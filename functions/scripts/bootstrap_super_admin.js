/**
 * Trusted Backend CLI Script: Bootstrap or Promote Super Admin
 * Usage: node bootstrap_super_admin.js <email>
 *
 * Exclusively assigns custom claims { role: 'super_admin', suspended: false }
 * Completely removes any reliance on hardcoded email comparisons.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const auth = admin.auth();
const db = admin.firestore();

async function bootstrapSuperAdmin(email) {
  if (!email || !email.includes('@')) {
    console.error('Error: Please provide a valid email address.');
    console.error('Usage: node bootstrap_super_admin.js <email>');
    process.exit(1);
  }

  const cleanEmail = email.trim().toLowerCase();
  console.log(`=== PROVISIONING SUPER ADMIN: ${cleanEmail} ===`);

  try {
    const userRecord = await auth.getUserByEmail(cleanEmail);
    const uid = userRecord.uid;

    // 1. Assign cryptographically signed custom claims
    await auth.setCustomUserClaims(uid, {
      role: 'super_admin',
      orgId: null,
      empId: null,
      suspended: false,
    });
    console.log(`✓ Custom Claims assigned: { role: 'super_admin' } for UID: ${uid}`);

    // 2. Sync /users/{uid} document
    await db.collection('users').doc(uid).set(
      {
        uid: uid,
        email: cleanEmail,
        role: 'super_admin',
        status: 'active',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`✓ Synchronized /users/${uid} document`);

    console.log(`\n========================================`);
    console.log(`SUCCESS: User ${cleanEmail} is now an authorized Super Admin.`);
    console.log(`========================================\n`);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.error(`Error: No Firebase Auth user found with email ${cleanEmail}.`);
      console.error(`Please create the user first or sign in once, then rerun this script.`);
    } else {
      console.error(`Error provisioning super admin:`, error);
    }
    process.exit(1);
  }
}

const targetEmail = process.argv[2];
if (!targetEmail) {
  console.error('Usage: node bootstrap_super_admin.js <email>');
  process.exit(1);
}

bootstrapSuperAdmin(targetEmail)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Process error:', err);
    process.exit(1);
  });

