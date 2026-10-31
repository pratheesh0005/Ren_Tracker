const functions = require("firebase-functions");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const auth = admin.auth();

/**
 * 1. Synchronize Custom Claims when /users/{uid} document is written.
 * Purely server-side; zero hardcoded emails.
 */
exports.syncUserClaims = functions.firestore
  .document("users/{uid}")
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    if (!change.after.exists) {
      return null;
    }

    const userData = change.after.data();
    const role = userData.role || "employee";
    const orgId = userData.orgId || null;
    const empId = userData.empId || null;
    const isSuspended = userData.status === "suspended";

    const claims = {
      role: role,
      orgId: role === "super_admin" ? null : orgId,
      empId: role === "employee" ? empId : null,
      suspended: isSuspended,
    };

    try {
      await auth.setCustomUserClaims(uid, claims);
      if (isSuspended) {
        await auth.revokeRefreshTokens(uid);
      }
      console.log(`Updated custom claims for user ${uid}:`, claims);
    } catch (error) {
      console.error(`Error setting custom claims for ${uid}:`, error);
    }
    return null;
  });

/**
 * 2. Global Organization Registration (Trusted Backend Callable)
 * Validates worldwide inputs, creates tenant, creates owner account,
 * assigns 'admin' Custom Claims securely.
 */
exports.registerOrganization = functions.https.onCall(async (data, context) => {
  const {
    name,
    ownerName,
    email,
    password,
    country,
    countryCode,
    phone,
    businessType,
    currency,
    currencySymbol,
    timeZone,
  } = data;

  if (!name || !email || !password) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Organization Name, Email, and Password are required."
    );
  }

  // Generate unique URL-safe orgId slug
  let slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  if (!slug || slug.length < 3) slug = "org";

  let finalOrgId = slug;
  let counter = 1;
  while ((await db.collection("organizations").doc(finalOrgId).get()).exists) {
    finalOrgId = `${slug}-${Math.floor(100 + Math.random() * 900)}`;
    counter++;
    if (counter > 10) break;
  }

  try {
    // 1. Create Firebase Auth user for owner
    const userRecord = await auth.createUser({
      email: email.trim().toLowerCase(),
      password: password,
      displayName: ownerName || name,
      phoneNumber: phone && phone.startsWith("+") ? phone : undefined,
    });

    // 2. Set Custom Claims (role: 'admin', orgId: finalOrgId)
    await auth.setCustomUserClaims(userRecord.uid, {
      role: "admin",
      orgId: finalOrgId,
      suspended: false,
    });

    // 3. Create Organization document with worldwide settings
    await db.collection("organizations").doc(finalOrgId).set({
      orgId: finalOrgId,
      name: name.trim(),
      ownerUid: userRecord.uid,
      adminEmail: email.trim().toLowerCase(),
      businessType: businessType || "General Business",
      country: country || "US",
      countryCode: countryCode || "+1",
      phone: phone || "",
      currency: currency || "USD",
      currencySymbol: currencySymbol || "$",
      timeZone: timeZone || "UTC",
      workingDays: [1, 2, 3, 4, 5], // Default Mon-Fri; customizable in settings
      standardWorkHours: 8.0,
      salaryBasis: "monthly_30",
      overtimeMultiplier: 1.5,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Create /users/{uid} document
    await db.collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: email.trim().toLowerCase(),
      name: ownerName || name,
      role: "admin",
      orgId: finalOrgId,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Add to members subcollection
    await db
      .collection("organizations")
      .doc(finalOrgId)
      .collection("members")
      .doc(userRecord.uid)
      .set({
        uid: userRecord.uid,
        email: email.trim().toLowerCase(),
        name: ownerName || name,
        role: "admin",
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    return {
      success: true,
      orgId: finalOrgId,
      uid: userRecord.uid,
      message: "Organization registered successfully.",
    };
  } catch (error) {
    console.error("Error registering organization:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * 3. Verify and Link Employee to Organization (Called after Phone OTP auth)
 */
exports.linkEmployeeAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated via Phone OTP.");
  }

  const callerUid = context.auth.uid;
  const callerPhone = context.auth.token.phone_number;
  const { orgId, empId } = data;

  if (!orgId || !empId) {
    throw new functions.https.HttpsError("invalid-argument", "Organization ID and Employee ID are required.");
  }

  const empRef = db.collection("organizations").doc(orgId).collection("employees").doc(empId);
  const empDoc = await empRef.get();

  if (!empDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Employee record not found in the specified organization.");
  }

  const empData = empDoc.data();
  // Normalize both phone numbers for comparison
  const cleanDocPhone = (empData.phone || "").replace(/\D/g, "");
  const cleanAuthPhone = (callerPhone || "").replace(/\D/g, "");

  if (!cleanAuthPhone || !cleanDocPhone.endsWith(cleanAuthPhone.slice(-10))) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Authenticated phone number does not match employee record."
    );
  }

  // Set Employee Custom Claims
  await auth.setCustomUserClaims(callerUid, {
    role: "employee",
    orgId: orgId,
    empId: empId,
    suspended: empData.status === "suspended",
  });

  // Link UID in employee doc and user record
  await empRef.update({
    linkedUid: callerUid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection("users").doc(callerUid).set(
    {
      uid: callerUid,
      phone: callerPhone,
      name: empData.name || "Employee",
      role: "employee",
      orgId: orgId,
      empId: empId,
      status: empData.status || "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { success: true, orgId, empId };
});

/**
 * 4. Suspend or Activate Organization (Super Admin Only)
 */
exports.setOrganizationSuspension = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== "super_admin") {
    throw new functions.https.HttpsError("permission-denied", "Super Admin access required.");
  }

  const { orgId, suspend } = data;
  if (!orgId) {
    throw new functions.https.HttpsError("invalid-argument", "Organization ID is required.");
  }

  await db.collection("organizations").doc(orgId).update({
    status: suspend ? "suspended" : "active",
    suspendedAt: suspend ? admin.firestore.FieldValue.serverTimestamp() : null,
  });

  return { success: true, orgId, status: suspend ? "suspended" : "active" };
});

/**
 * 5. Suspend or Activate User Account
 */
exports.setUserSuspension = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const { targetUid, suspend } = data;
  const callerRole = context.auth.token.role;
  const callerOrgId = context.auth.token.orgId;

  if (callerRole !== "super_admin" && callerRole !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Unauthorized action.");
  }

  if (callerRole === "admin") {
    const targetUserDoc = await db.collection("users").doc(targetUid).get();
    if (!targetUserDoc.exists || targetUserDoc.data().orgId !== callerOrgId) {
      throw new functions.https.HttpsError("permission-denied", "Cannot modify user outside your organization.");
    }
  }

  await db.collection("users").doc(targetUid).update({
    status: suspend ? "suspended" : "active",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update claims and revoke active session tokens
  const currentClaims = (await auth.getUser(targetUid)).customClaims || {};
  await auth.setCustomUserClaims(targetUid, {
    ...currentClaims,
    suspended: suspend,
  });

  if (suspend) {
    await auth.revokeRefreshTokens(targetUid);
  }

  return { success: true, targetUid, suspended: suspend };
});

/**
 * 6. Send Tenant Notification
 */
exports.sendTenantNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Authentication required.");
  }

  const callerRole = context.auth.token.role;
  const callerOrgId = context.auth.token.orgId;

  if (callerRole !== "super_admin" && callerRole !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Only administrators can broadcast notifications.");
  }

  const { title, message, orgId } = data;
  const targetOrg = callerRole === "super_admin" ? orgId : callerOrgId;

  if (!title || !message) {
    throw new functions.https.HttpsError("invalid-argument", "Title and message are required.");
  }

  await db.collection("organizations").doc(targetOrg).collection("notifications").add({
    title: title.trim(),
    message: message.trim(),
    sentBy: context.auth.token.email || "Admin",
    date: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

