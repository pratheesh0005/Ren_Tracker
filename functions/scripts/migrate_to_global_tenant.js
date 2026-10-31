/**
 * Idempotent Global SaaS Migration Script
 * Migrates Renish Electronics into Tenant #1 with global settings:
 * Country: IN (+91), Currency: INR (₹), Timezone: Asia/Kolkata,
 * Salary Basis: monthly_26, Working Days: [1..6] (Mon-Sat).
 * Migrates employees, attendance, notifications, and isolates salary records under
 * /organizations/{orgId}/employees/{empId}/salary/{periodId}.
 * Does NOT delete any legacy root collections.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const TARGET_ORG = process.env.DEFAULT_ORG_ID || 'ren_tracker';

async function runGlobalMigration() {
  console.log(`=== STARTING IDEMPOTENT GLOBAL SAAS MIGRATION FOR ${TARGET_ORG} ===`);

  // 1. Establish Tenant #1 with Global Configuration
  const orgRef = db.collection('organizations').doc(TARGET_ORG);
  await orgRef.set(
    {
      orgId: TARGET_ORG,
      name: TARGET_ORG === 'renish_electronics' ? 'Renish Electronics' : 'Ren Tracker',
      businessType: 'Manufacturing & Technology',
      country: 'IN',
      countryCode: '+91',
      currency: 'INR',
      currencySymbol: '₹',
      timeZone: 'Asia/Kolkata',
      workingDays: [1, 2, 3, 4, 5, 6], // Monday through Saturday
      standardWorkHours: 8.0,
      salaryBasis: 'monthly_26',
      overtimeMultiplier: 1.5,
      status: 'active',
      isGlobalTenant: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`✓ Configured global organization doc: /organizations/${TARGET_ORG}`);

  // 2. Migrate Employees with E.164 phone normalization
  const empSnap = await db.collection('employees').get();
  let empsCount = 0;
  for (const doc of empSnap.docs) {
    const rawData = doc.data();
    const rawPhone = (rawData.phone || '').toString().trim();
    const cleanDigits = rawPhone.replace(/\D/g, '');
    const phoneE164 = cleanDigits.length === 10 ? `+91${cleanDigits}` : (rawPhone.startsWith('+') ? rawPhone : `+${rawPhone}`);

    await orgRef.collection('employees').doc(doc.id).set(
      {
        ...rawData,
        empId: doc.id,
        orgId: TARGET_ORG,
        phone: phoneE164,
        countryCode: '+91',
        salaryType: rawData.salaryType || 'monthly',
        baseSalary: Number(rawData.salary) || 0,
        status: rawData.status || 'active',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    empsCount++;
  }
  console.log(`✓ Migrated & normalized ${empsCount} employees to tenant`);

  // 3. Migrate Attendance records
  const attSnap = await db.collection('attendance').get();
  let dateCount = 0;
  let recordCount = 0;

  for (const dateDoc of attSnap.docs) {
    const recSnap = await db.collection('attendance').doc(dateDoc.id).collection('records').get();
    for (const recDoc of recSnap.docs) {
      await orgRef
        .collection('attendance')
        .doc(dateDoc.id)
        .collection('records')
        .doc(recDoc.id)
        .set(
          {
            ...recDoc.data(),
            orgId: TARGET_ORG,
            empId: recDoc.id,
            date: dateDoc.id,
          },
          { merge: true }
        );
      recordCount++;
    }
    dateCount++;
  }
  console.log(`✓ Migrated ${recordCount} attendance records across ${dateCount} dates to tenant`);

  // 4. Migrate Notifications
  const notifSnap = await db.collection('notifications').get();
  let notifsCount = 0;
  for (const doc of notifSnap.docs) {
    await orgRef.collection('notifications').doc(doc.id).set(
      {
        ...doc.data(),
        orgId: TARGET_ORG,
      },
      { merge: true }
    );
    notifsCount++;
  }
  console.log(`✓ Migrated ${notifsCount} notifications to tenant`);

  // 5. Isolate Salary records under /organizations/{orgId}/employees/{empId}/salary/{periodId}
  const rootSalarySnap = await orgRef.collection('salary').get();
  let salaryMigratedCount = 0;
  for (const salDoc of rootSalarySnap.docs) {
    const salData = salDoc.data();
    const empId = salData.empId || salDoc.id.split('_')[0];
    const periodId = salData.periodFrom && salData.periodTo
      ? `${salData.periodFrom}_${salData.periodTo}`
      : salDoc.id;

    if (empId) {
      await orgRef
        .collection('employees')
        .doc(empId)
        .collection('salary')
        .doc(periodId)
        .set(
          {
            ...salData,
            empId: empId,
            periodId: periodId,
            currency: 'INR',
            currencySymbol: '₹',
            migratedToSubcollection: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      salaryMigratedCount++;
    }
  }
  console.log(`✓ Isolated ${salaryMigratedCount} salary documents into employee subcollections`);

  console.log(`\n========================================`);
  console.log(`MIGRATION COMPLETE: Renish Electronics is now Tenant #1`);
  console.log(`========================================\n`);
}

if (require.main === module) {
  runGlobalMigration()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Migration failed:', err);
      process.exit(1);
    });
}

module.exports = { runGlobalMigration };

