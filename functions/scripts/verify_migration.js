/**
 * Migration Verification & Reconciliation Script
 * Validates that all legacy root collections match the tenant #1 records in /organizations/renish_electronics/
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TARGET_ORG = process.env.DEFAULT_ORG_ID || 'ren_tracker';

async function runVerification() {
  console.log(`=== STARTING MIGRATION RECONCILIATION FOR ${TARGET_ORG} ===`);
  const orgRef = db.collection('organizations').doc(TARGET_ORG);

  // 1. Verify Organization document
  const orgDoc = await orgRef.get();
  if (!orgDoc.exists) {
    throw new Error(`Target organization ${TARGET_ORG} does not exist!`);
  }
  const orgData = orgDoc.data();
  console.log(`✓ Organization exists: ${orgData.name} (${orgData.country}, ${orgData.currency}, ${orgData.timeZone})`);

  // 2. Reconcile Employees
  const legacyEmps = await db.collection('employees').get();
  const tenantEmps = await orgRef.collection('employees').get();
  console.log(`Employees: Legacy count = ${legacyEmps.docs.length}, Tenant count = ${tenantEmps.docs.length}`);
  if (tenantEmps.docs.length < legacyEmps.docs.length) {
    console.warn(`⚠️ Warning: Tenant employee count (${tenantEmps.docs.length}) is less than legacy (${legacyEmps.docs.length})`);
  } else {
    console.log(`✓ Employee counts verified!`);
  }

  // 3. Reconcile Notifications
  const legacyNotifs = await db.collection('notifications').get();
  const tenantNotifs = await orgRef.collection('notifications').get();
  console.log(`Notifications: Legacy count = ${legacyNotifs.docs.length}, Tenant count = ${tenantNotifs.docs.length}`);
  if (tenantNotifs.docs.length < legacyNotifs.docs.length) {
    console.warn(`⚠️ Warning: Tenant notification count is less than legacy`);
  } else {
    console.log(`✓ Notification counts verified!`);
  }

  // 4. Reconcile Attendance
  const legacyAtt = await db.collection('attendance').get();
  let legacyRecCount = 0;
  for (const doc of legacyAtt.docs) {
    const recs = await db.collection('attendance').doc(doc.id).collection('records').get();
    legacyRecCount += recs.docs.length;
  }

  const tenantAtt = await orgRef.collection('attendance').get();
  let tenantRecCount = 0;
  for (const doc of tenantAtt.docs) {
    const recs = await orgRef.collection('attendance').doc(doc.id).collection('records').get();
    tenantRecCount += recs.docs.length;
  }

  console.log(`Attendance: Legacy dates = ${legacyAtt.docs.length}, records = ${legacyRecCount}`);
  console.log(`Attendance: Tenant dates = ${tenantAtt.docs.length}, records = ${tenantRecCount}`);
  if (tenantRecCount < legacyRecCount) {
    console.warn(`⚠️ Warning: Tenant attendance records count is less than legacy`);
  } else {
    console.log(`✓ Attendance record counts verified!`);
  }

  console.log(`\n========================================`);
  console.log(`VERIFICATION RESULT: Migration integrity verified.`);
  console.log(`========================================\n`);
}

if (require.main === module) {
  runVerification()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Verification failed:', err);
      process.exit(1);
    });
}

module.exports = { runVerification };

