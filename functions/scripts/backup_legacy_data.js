/**
 * Pre-Migration Backup Script
 * Exports full JSON snapshot of legacy root collections:
 * /employees, /attendance, /notifications, /settings, /users
 * Stored locally in backups/pre_migration_backup_<timestamp>.json
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function runBackup() {
  console.log('=== STARTING PRE-MIGRATION DATA BACKUP ===');
  const backupData = {
    timestamp: new Date().toISOString(),
    collections: {},
  };

  // 1. Employees
  console.log('Backing up /employees...');
  const empSnap = await db.collection('employees').get();
  backupData.collections.employees = empSnap.docs.map(d => ({ id: d.id, data: d.data() }));
  console.log(`✓ Backed up ${empSnap.docs.length} employees`);

  // 2. Notifications
  console.log('Backing up /notifications...');
  const notifSnap = await db.collection('notifications').get();
  backupData.collections.notifications = notifSnap.docs.map(d => ({ id: d.id, data: d.data() }));
  console.log(`✓ Backed up ${notifSnap.docs.length} notifications`);

  // 3. Settings
  console.log('Backing up /settings...');
  const settingsSnap = await db.collection('settings').get();
  backupData.collections.settings = settingsSnap.docs.map(d => ({ id: d.id, data: d.data() }));
  console.log(`✓ Backed up ${settingsSnap.docs.length} settings docs`);

  // 4. Users
  console.log('Backing up /users...');
  const usersSnap = await db.collection('users').get();
  backupData.collections.users = usersSnap.docs.map(d => ({ id: d.id, data: d.data() }));
  console.log(`✓ Backed up ${usersSnap.docs.length} users`);

  // 5. Attendance (including subcollection records)
  console.log('Backing up /attendance dates & records...');
  const attSnap = await db.collection('attendance').get();
  backupData.collections.attendance = [];
  let recordTotal = 0;

  for (const dateDoc of attSnap.docs) {
    const recSnap = await db.collection('attendance').doc(dateDoc.id).collection('records').get();
    const records = recSnap.docs.map(r => ({ id: r.id, data: r.data() }));
    recordTotal += records.length;
    backupData.collections.attendance.push({
      date: dateDoc.id,
      dateData: dateDoc.data(),
      records: records,
    });
  }
  console.log(`✓ Backed up ${recordTotal} attendance records across ${attSnap.docs.length} dates`);

  // Ensure backup directory
  const backupDir = path.join(__dirname, '..', '..', 'backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestampStr = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFilePath = path.join(backupDir, `pre_migration_backup_${timestampStr}.json`);
  fs.writeFileSync(backupFilePath, JSON.stringify(backupData, null, 2), 'utf-8');

  console.log(`\n========================================`);
  console.log(`SUCCESS: Full snapshot written to:`);
  console.log(backupFilePath);
  console.log(`========================================\n`);
  return backupFilePath;
}

if (require.main === module) {
  runBackup()
    .then(() => process.exit(0))
    .catch(err => {
      console.error('Backup failed:', err);
      process.exit(1);
    });
}

module.exports = { runBackup };

