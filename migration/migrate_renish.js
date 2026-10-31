/**
 * Safe, Non-Destructive Data Migration Script
 * Mirrors Renish Electronics legacy collections into organizations/renish_electronics/
 * Does NOT delete any legacy records.
 */

const admin = require("firebase-admin");

// Initialize admin SDK (uses GOOGLE_APPLICATION_CREDENTIALS or default credentials)
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TARGET_ORG = process.env.DEFAULT_ORG_ID || "ren_tracker";

async function runMigration() {
  console.log(`=== STARTING NON-DESTRUCTIVE MIGRATION FOR ${TARGET_ORG} ===`);

  // 1. Ensure Organization
  const orgRef = db.collection("organizations").doc(TARGET_ORG);
  await orgRef.set(
    {
      name: TARGET_ORG === "renish_electronics" ? "Renish Electronics" : "Ren Tracker",
      orgId: TARGET_ORG,
      status: "active",
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`✓ Provisioned organizations/${TARGET_ORG}`);

  // 2. Migrate Employees
  const empSnap = await db.collection("employees").get();
  let empsCount = 0;
  for (const doc of empSnap.docs) {
    await orgRef
      .collection("employees")
      .doc(doc.id)
      .set(
        {
          ...doc.data(),
          orgId: TARGET_ORG,
          status: doc.data().status || "active",
        },
        { merge: true }
      );
    empsCount++;
  }
  console.log(`✓ Migrated ${empsCount} employees`);

  // 3. Migrate Notifications
  const notifSnap = await db.collection("notifications").get();
  let notifsCount = 0;
  for (const doc of notifSnap.docs) {
    await orgRef
      .collection("notifications")
      .doc(doc.id)
      .set(
        {
          ...doc.data(),
          orgId: TARGET_ORG,
        },
        { merge: true }
      );
    notifsCount++;
  }
  console.log(`✓ Migrated ${notifsCount} notifications`);

  // 4. Migrate Attendance
  const attSnap = await db.collection("attendance").get();
  let dateCount = 0;
  let recordCount = 0;
  for (const dateDoc of attSnap.docs) {
    const recSnap = await db
      .collection("attendance")
      .doc(dateDoc.id)
      .collection("records")
      .get();
    for (const recDoc of recSnap.docs) {
      await orgRef
        .collection("attendance")
        .doc(dateDoc.id)
        .collection("records")
        .doc(recDoc.id)
        .set(
          {
            ...recDoc.data(),
            orgId: TARGET_ORG,
          },
          { merge: true }
        );
      recordCount++;
    }
    dateCount++;
  }
  console.log(`✓ Migrated ${recordCount} attendance entries across ${dateCount} dates`);

  // 5. Link Admin Members
  const admins = []; // Add your admin emails here, e.g. ["admin@yourorg.com"]
  for (const email of admins) {
    const userSnap = await db.collection("users").where("email", "==", email).get();
    if (!userSnap.empty) {
      const uid = userSnap.docs[0].id;
      await orgRef
        .collection("members")
        .doc(uid)
        .set(
          {
            uid: uid,
            email: email,
            role: "admin",
            status: "active",
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      console.log(`✓ Linked admin member: ${email}`);
    }
  }

  console.log("=== MIGRATION COMPLETED SUCCESSFULLY WITHOUT ANY DATA LOSS ===");
}

runMigration().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});

