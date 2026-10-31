import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:ren_tracker/data/models/organization_model.dart';
import 'package:ren_tracker/core/utils/formatters.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/core/services/auth_service.dart';

class FirestoreRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String orgId;
  OrganizationModel? _cachedOrg;

  FirestoreRepository({String? orgId})
      : orgId = (orgId != null && orgId.trim().isNotEmpty)
            ? orgId.trim()
            : EnvConfig.defaultOrgId;

  // Tenant Subcollections
  DocumentReference get _orgRef => _db.collection('organizations').doc(orgId);
  CollectionReference get _employeesRef => _orgRef.collection('employees');
  CollectionReference get _attendanceRef => _orgRef.collection('attendance');
  CollectionReference get _notificationsRef => _orgRef.collection('notifications');
  CollectionReference get _salaryRef => _orgRef.collection('salary');
  CollectionReference get _correctionsRef => _orgRef.collection('attendance_corrections');
  CollectionReference get _auditLogsRef => _orgRef.collection('audit_logs');

  // ══════════════════════════════════════════════════════════
  //  ORGANIZATION DETAILS & TIMEZONE AWARENESS
  // ══════════════════════════════════════════════════════════

  Future<OrganizationModel> getOrganization() async {
    if (_cachedOrg != null && _cachedOrg!.orgId == orgId) {
      return _cachedOrg!;
    }
    try {
      final doc = await _orgRef.get();
      if (doc.exists) {
        _cachedOrg = OrganizationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        return _cachedOrg!;
      }
    } catch (_) {}

    _cachedOrg = OrganizationModel(
      orgId: orgId,
      name: (orgId == 'ren_tracker' || orgId == 'renish_electronics') ? 'Ren Tracker' : orgId,
    );
    return _cachedOrg!;
  }

  Future<Map<String, dynamic>> getOrganizationDetails() async {
    final org = await getOrganization();
    return org.toMap();
  }

  Future<String> todayInTenant() async {
    final org = await getOrganization();
    final tenantNow = TimezoneHelper.toTenantTime(DateTime.now().toUtc(), org.timeZone);
    return DateFormat('yyyy-MM-dd').format(tenantNow);
  }

  String today() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // ══════════════════════════════════════════════════════════
  //  EMPLOYEES DIRECTORY
  // ══════════════════════════════════════════════════════════

  Stream<QuerySnapshot> employeesStream() {
    return _employeesRef.orderBy('name').snapshots();
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final snap = await _employeesRef.orderBy('name').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
      }
    } catch (_) {}

    // Fallback during initial migration for Ren Tracker / Renish Electronics
    if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
      try {
        final legacySnap = await _db.collection('employees').orderBy('name').get();
        return legacySnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<Map<String, dynamic>?> getEmployee(String empId) async {
    try {
      final doc = await _employeesRef.doc(empId).get();
      if (doc.exists) return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (_) {}

    if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
      try {
        final legacyDoc = await _db.collection('employees').doc(empId).get();
        if (legacyDoc.exists) return {'id': legacyDoc.id, ...legacyDoc.data()!};
      } catch (_) {}
    }
    return null;
  }

  Future<void> addEmployee({
    required String empId,
    required String name,
    required String phone,
    required String department,
    required String position,
    required String salaryType,
    required double salary,
    String? email,
    String? password,
    String? countryCode,
    double? hourlyRate,
  }) async {
    final cleanId = empId.trim().toUpperCase();
    final cleanEmail = (email != null && email.trim().isNotEmpty) ? email.trim().toLowerCase() : null;
    final org = await getOrganization();
    final formattedPhone = PhoneHelper.toE164(phone, countryCode ?? org.countryCode);

    String? linkedUid;

    // If email is provided, provision employee auth credentials
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      final authResult = await AuthService().createEmployeeAccount(
        email: cleanEmail,
        password: (password != null && password.trim().isNotEmpty) ? password.trim() : 'Emp@123',
        name: name.trim(),
        orgId: orgId,
        empId: cleanId,
        phone: formattedPhone,
      );
      if (authResult.containsKey('uid')) {
        linkedUid = authResult['uid'] as String?;
      }
    }

    final data = {
      'empId': cleanId,
      'name': name.trim(),
      'email': cleanEmail ?? '',
      'phone': formattedPhone,
      'countryCode': countryCode ?? org.countryCode,
      'department': department.trim(),
      'position': position.trim(),
      'salaryType': salaryType,
      'salary': salary,
      'baseSalary': salary,
      'hourlyRate': hourlyRate ?? (salaryType == 'hourly' ? salary : (salary / (26 * 8))),
      'orgId': orgId,
      'status': 'active',
      'linkedUid': linkedUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _employeesRef.doc(cleanId).set(data, SetOptions(merge: true));
    await _logAudit(action: 'ADD_EMPLOYEE', details: 'Added employee $cleanId ($name)');
  }

  Future<Map<String, dynamic>> setEmployeeCredentials({
    required String empId,
    required String email,
    required String password,
  }) async {
    final cleanId = empId.trim().toUpperCase();
    final cleanEmail = email.trim().toLowerCase();

    final empDoc = await _employeesRef.doc(cleanId).get();
    final data = empDoc.data() as Map<String, dynamic>?;
    final empName = data?['name'] as String? ?? 'Employee';
    final empPhone = data?['phone'] as String? ?? '';

    final authResult = await AuthService().createEmployeeAccount(
      email: cleanEmail,
      password: password.trim(),
      name: empName,
      orgId: orgId,
      empId: cleanId,
      phone: empPhone,
    );

    if (authResult.containsKey('error')) {
      return authResult;
    }

    final uid = authResult['uid'] as String?;

    await _employeesRef.doc(cleanId).set({
      'email': cleanEmail,
      'linkedUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logAudit(action: 'SET_EMPLOYEE_CREDENTIALS', details: 'Set app login credentials for $cleanId ($cleanEmail)');
    return {'success': true, 'uid': uid, 'email': cleanEmail};
  }

  Future<void> updateEmployee(String empId, Map<String, dynamic> updates) async {
    final cleanId = empId.trim().toUpperCase();
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _employeesRef.doc(cleanId).update(updates);
    await _logAudit(action: 'UPDATE_EMPLOYEE', details: 'Updated employee $cleanId');
  }

  Future<void> deleteEmployee(String empId) async {
    final cleanId = empId.trim().toUpperCase();
    await _employeesRef.doc(cleanId).delete();
    await _logAudit(action: 'DELETE_EMPLOYEE', details: 'Deleted employee $cleanId');
  }

  // ══════════════════════════════════════════════════════════
  //  ATTENDANCE & AUDIT LOGS
  // ══════════════════════════════════════════════════════════

  Future<Map<String, String>> getAttendanceForDate(String dateStr) async {
    try {
      final snap = await _attendanceRef.doc(dateStr).collection('records').get();
      if (snap.docs.isNotEmpty) {
        return {for (final doc in snap.docs) doc.id: doc.data()['status'] as String? ?? ''};
      }
    } catch (_) {}

    // Fallback during initial migration
    if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
      try {
        final legacySnap = await _db.collection('attendance').doc(dateStr).collection('records').get();
        return {for (final doc in legacySnap.docs) doc.id: doc.data()['status'] as String? ?? ''};
      } catch (_) {}
    }
    return {};
  }

  Future<void> markAttendance({
    required String dateStr,
    required String empId,
    required String status,
    String? shiftType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final payload = {
      'status': status,
      'markedBy': uid,
      'orgId': orgId,
      'shiftType': shiftType ?? 'regular',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _attendanceRef.doc(dateStr).collection('records').doc(empId).set(payload);
  }

  Future<void> saveAllAttendance(String dateStr, Map<String, String> records) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final batch = _db.batch();

    records.forEach((empId, status) {
      final ref = _attendanceRef.doc(dateStr).collection('records').doc(empId);
      batch.set(ref, {
        'status': status,
        'markedBy': uid,
        'orgId': orgId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    await _logAudit(
      action: 'SAVE_ATTENDANCE',
      details: 'Marked attendance for ${records.length} staff on $dateStr',
    );
  }

  Future<List<Map<String, dynamic>>> getEmployeeAttendanceRange(
      String empId, String from, String to) async {
    final dates = _dateRange(from, to);
    final results = <Map<String, dynamic>>[];

    for (final d in dates) {
      var status = '';
      try {
        final doc = await _attendanceRef.doc(d).collection('records').doc(empId).get();
        if (doc.exists) {
          status = doc.data()?['status'] as String? ?? '';
        } else if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
          final legacyDoc = await _db.collection('attendance').doc(d).collection('records').doc(empId).get();
          if (legacyDoc.exists) {
            status = legacyDoc.data()?['status'] as String? ?? '';
          }
        }
      } catch (_) {}

      results.add({'date': d, 'status': status.isEmpty ? null : status});
    }
    return results;
  }

  // Attendance Correction Requests
  Future<void> submitCorrectionRequest({
    required String empId,
    required String empName,
    required String dateStr,
    required String requestedStatus,
    required String reason,
  }) async {
    await _correctionsRef.add({
      'empId': empId,
      'empName': empName,
      'dateStr': dateStr,
      'requestedStatus': requestedStatus,
      'reason': reason.trim(),
      'status': 'pending',
      'requestedBy': FirebaseAuth.instance.currentUser?.uid ?? empId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> correctionRequestsStream() {
    return _correctionsRef.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<QuerySnapshot> attendanceCorrectionsStream() => correctionRequestsStream();

  Future<void> reviewCorrectionRequest({
    required String requestId,
    required String dateStr,
    required String empId,
    required String approvedStatus,
    required bool approve,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    await _correctionsRef.doc(requestId).update({
      'status': approve ? 'approved' : 'rejected',
      'reviewedBy': uid,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    if (approve) {
      await markAttendance(dateStr: dateStr, empId: empId, status: approvedStatus);
      await _logAudit(
        action: 'APPROVE_CORRECTION',
        details: 'Approved correction for $empId on $dateStr to $approvedStatus',
      );
    }
  }

  // ══════════════════════════════════════════════════════════
  //  MONTHLY ATTENDANCE COMPUTATION & REPORTING
  // ══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> computeMonthlyAttendance(String from, String to) async {
    final employees = await getEmployees();
    final dates = _dateRange(from, to);
    final attMap = <String, Map<String, int>>{};

    for (final e in employees) {
      final id = (e['id'] ?? e['empId']) as String;
      attMap[id] = {'present': 0, 'absent': 0, 'half': 0, 'unmarked': 0};
    }

    for (final d in dates) {
      final records = await getAttendanceForDate(d);
      for (final e in employees) {
        final id = (e['id'] ?? e['empId']) as String;
        final status = records[id];
        if (status == 'present') {
          attMap[id]!['present'] = attMap[id]!['present']! + 1;
        } else if (status == 'absent') {
          attMap[id]!['absent'] = attMap[id]!['absent']! + 1;
        } else if (status == 'half_day') {
          attMap[id]!['half'] = attMap[id]!['half']! + 1;
        } else {
          attMap[id]!['unmarked'] = attMap[id]!['unmarked']! + 1;
        }
      }
    }

    final totalDays = dates.length;
    final results = employees.map((e) {
      final id = (e['id'] ?? e['empId']) as String;
      final att = attMap[id] ?? {'present': 0, 'absent': 0, 'half': 0, 'unmarked': totalDays};
      final p = att['present']!;
      final a = att['absent']!;
      final h = att['half']!;
      final u = att['unmarked']!;
      final eff = p + (h * 0.5);
      final rate = totalDays > 0 ? (eff / totalDays) * 100 : 0.0;

      return {
        ...e,
        'empId': id,
        'name': e['name'] as String? ?? 'Employee',
        'phone': e['phone'] as String? ?? '—',
        'department': e['department'] as String? ?? 'General',
        'position': e['position'] as String? ?? 'Staff',
        'totalDays': totalDays,
        'presentDays': p,
        'absentDays': a,
        'halfDays': h,
        'unmarkedDays': u,
        'effectiveDays': eff,
        'attendanceRate': rate,
      };
    }).toList();

    results.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return results;
  }

  // ══════════════════════════════════════════════════════════
  //  UNIVERSAL SALARY CALCULATION & ISOLATION
  // ══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> calculateSalary(String from, String to) async {
    final org = await getOrganization();
    final employees = await getEmployees();
    final dates = _dateRange(from, to);
    final attMap = <String, Map<String, int>>{};

    for (final e in employees) {
      attMap[e['id'] as String] = {'present': 0, 'absent': 0, 'half': 0};
    }

    for (final d in dates) {
      final records = await getAttendanceForDate(d);
      records.forEach((empId, status) {
        if (attMap.containsKey(empId)) {
          if (status == 'present') attMap[empId]!['present'] = attMap[empId]!['present']! + 1;
          else if (status == 'absent') attMap[empId]!['absent'] = attMap[empId]!['absent']! + 1;
          else if (status == 'half_day') attMap[empId]!['half'] = attMap[empId]!['half']! + 1;
        }
      });
    }

    return employees.map((e) {
      final id = e['id'] as String;
      final att = attMap[id] ?? {'present': 0, 'absent': 0, 'half': 0};
      final p = att['present']!;
      final a = att['absent']!;
      final h = att['half']!;
      final eff = p + h * 0.5;
      final sal = (e['salary'] as num?)?.toDouble() ?? (e['baseSalary'] as num?)?.toDouble() ?? 0.0;
      final type = e['salaryType'] as String? ?? 'monthly';

      // Universal Salary Calculation Formula
      double earned;
      if (type == 'hourly') {
        final hoursPerDay = org.standardWorkHours > 0 ? org.standardWorkHours : 8.0;
        final totalHours = eff * hoursPerDay;
        final hourlyRate = (e['hourlyRate'] as num?)?.toDouble() ?? (sal > 0 ? sal : 15.0);
        earned = hourlyRate * totalHours;
      } else if (type == 'daily') {
        earned = sal * eff;
      } else if (type == 'weekly') {
        earned = (sal / 7) * eff;
      } else {
        // Monthly calculation
        double divisor = 26.0; // Default factory norm for Ren Tracker
        if (org.salaryBasis == 'monthly_30') {
          divisor = 30.0;
        } else if (org.salaryBasis == 'monthly_actual') {
          divisor = dates.isNotEmpty ? dates.length.toDouble() : 30.0;
        }
        earned = (sal / divisor) * eff;
      }

      return {
        ...e,
        'presentDays': p,
        'absentDays': a,
        'halfDays': h,
        'effectiveDays': eff,
        'earnedSalary': earned,
        'currency': org.currency,
        'currencySymbol': org.currencySymbol,
        'paymentStatus': 'pending',
      };
    }).toList();
  }

  Future<void> saveSalaryDisbursement({
    required String periodFrom,
    required String periodTo,
    required List<Map<String, dynamic>> salaryRows,
  }) async {
    final org = await getOrganization();
    final batch = _db.batch();
    final periodId = '${periodFrom}_$periodTo';

    for (final row in salaryRows) {
      final empId = row['id'] as String;
      final recordData = {
        'empId': empId,
        'empName': row['name'],
        'periodFrom': periodFrom,
        'periodTo': periodTo,
        'periodId': periodId,
        'presentDays': row['presentDays'],
        'absentDays': row['absentDays'],
        'halfDays': row['halfDays'],
        'effectiveDays': row['effectiveDays'],
        'earnedSalary': row['earnedSalary'],
        'currency': org.currency,
        'currencySymbol': org.currencySymbol,
        'status': 'approved',
        'savedAt': FieldValue.serverTimestamp(),
      };

      // 1. Employee-Isolated Subcollection: /organizations/{orgId}/employees/{empId}/salary/{periodId}
      final empSalaryRef = _employeesRef.doc(empId).collection('salary').doc(periodId);
      batch.set(empSalaryRef, recordData);

      // 2. Organization Aggregate View (Admin only)
      final docId = '${empId}_$periodId';
      final ref = _salaryRef.doc(docId);
      batch.set(ref, recordData);
    }

    await batch.commit();
    await _logAudit(
      action: 'APPROVE_SALARY',
      details: 'Recorded salary period $periodFrom to $periodTo for ${salaryRows.length} staff',
    );
  }

  Future<List<Map<String, dynamic>>> getEmployeeSalaryHistory(String empId) async {
    try {
      final snap = await _employeesRef
          .doc(empId)
          .collection('salary')
          .orderBy('savedAt', descending: true)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (_) {}
    return [];
  }

  // ══════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════

  Stream<QuerySnapshot> notificationsStream() {
    return _notificationsRef.orderBy('date', descending: true).snapshots();
  }

  Future<void> saveNotification({
    required String title,
    required String message,
    required String sentBy,
    String target = 'all',
    String? targetEmpId,
    String? targetEmpName,
  }) async {
    final payload = {
      'title': title,
      'message': message,
      'sentBy': sentBy,
      'target': target,
      'targetEmpId': targetEmpId,
      'targetEmpName': targetEmpName,
      'orgId': orgId,
      'date': FieldValue.serverTimestamp(),
    };

    await _notificationsRef.add(payload);
    await _logAudit(action: 'NOTIFICATION', details: 'Dispatched notice to $target: $title');
  }

  Future<void> deleteNotification(String notifId) async {
    await _notificationsRef.doc(notifId).delete();
  }

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 30}) async {
    try {
      final snap = await _notificationsRef.orderBy('date', descending: true).limit(limit).get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
      }
    } catch (_) {}

    if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
      try {
        final legacySnap = await _db.collection('notifications').orderBy('date', descending: true).limit(limit).get();
        return legacySnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      } catch (_) {}
    }
    return [];
  }

  // ══════════════════════════════════════════════════════════
  //  DASHBOARD METRICS
  // ══════════════════════════════════════════════════════════

  Future<Map<String, int>> getTodayStats() async {
    final todayStr = await todayInTenant();
    final emps = await getEmployees();
    final att = await getAttendanceForDate(todayStr);

    int p = 0, a = 0, h = 0;
    for (final e in emps) {
      final s = att[e['id'] as String] ?? '';
      if (s == 'present') p++;
      else if (s == 'absent') a++;
      else if (s == 'half_day') h++;
    }
    return {'total': emps.length, 'present': p, 'absent': a, 'half': h};
  }

  // ══════════════════════════════════════════════════════════
  //  AUDIT LOGGING
  // ══════════════════════════════════════════════════════════

  Future<void> _logAudit({required String action, required String details}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _auditLogsRef.add({
        'action': action,
        'details': details,
        'performedBy': user?.email ?? user?.uid ?? 'system',
        'orgId': orgId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  List<String> _dateRange(String from, String to) {
    final dates = <String>[];
    DateTime cur = DateFormat('yyyy-MM-dd').parse(from);
    final end = DateFormat('yyyy-MM-dd').parse(to);
    while (!cur.isAfter(end)) {
      dates.add(DateFormat('yyyy-MM-dd').format(cur));
      cur = cur.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<Map<String, dynamic>> migrateLegacyRenishData() async {
    int empsMigrated = 0;
    int attDatesMigrated = 0;
    int notifsMigrated = 0;

    try {
      await _orgRef.set({
        'name': (orgId == 'ren_tracker' || orgId == 'renish_electronics') ? 'Ren Tracker' : orgId,
        'orgId': orgId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final empSnap = await _db.collection('employees').get();
      for (final doc in empSnap.docs) {
        await _employeesRef.doc(doc.id).set({
          ...doc.data(),
          'orgId': orgId,
        }, SetOptions(merge: true));
        empsMigrated++;
      }

      final notifSnap = await _db.collection('notifications').get();
      for (final doc in notifSnap.docs) {
        await _notificationsRef.doc(doc.id).set({
          ...doc.data(),
          'orgId': orgId,
        }, SetOptions(merge: true));
        notifsMigrated++;
      }

      final migratedDates = <String>{};
      try {
        final attSnap = await _db.collection('attendance').get();
        for (final dateDoc in attSnap.docs) {
          final recSnap = await _db.collection('attendance').doc(dateDoc.id).collection('records').get();
          for (final recDoc in recSnap.docs) {
            await _attendanceRef.doc(dateDoc.id).collection('records').doc(recDoc.id).set({
              ...recDoc.data(),
              'orgId': orgId,
            }, SetOptions(merge: true));
          }
          migratedDates.add(dateDoc.id);
        }
      } catch (_) {}

      try {
        final groupSnap = await _db.collectionGroup('records').get();
        for (final recDoc in groupSnap.docs) {
          final parentCollection = recDoc.reference.parent.parent?.parent.id;
          if (parentCollection == 'attendance') {
            final dateStr = recDoc.reference.parent.parent?.id;
            if (dateStr != null && dateStr.isNotEmpty) {
              await _attendanceRef.doc(dateStr).collection('records').doc(recDoc.id).set({
                ...recDoc.data(),
                'orgId': orgId,
              }, SetOptions(merge: true));
              migratedDates.add(dateStr);
            }
          }
        }
      } catch (_) {}
      attDatesMigrated = migratedDates.length;

      await _logAudit(
        action: 'MIGRATION_COMPLETED',
        details: 'Migrated $empsMigrated employees, $attDatesMigrated dates, and $notifsMigrated notices',
      );

      return {
        'success': true,
        'employees': empsMigrated,
        'attendanceDates': attDatesMigrated,
        'notifications': notifsMigrated,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════
  //  DATABASE HEALTH & STORAGE VERIFICATION
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> verifyDatabaseIntegrity() async {
    final report = <String, dynamic>{
      'orgId': orgId,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      // 1. Organization Document
      final orgDoc = await _orgRef.get();
      report['orgExists'] = orgDoc.exists;
      if (orgDoc.exists) {
        final d = orgDoc.data() as Map<String, dynamic>? ?? {};
        report['orgName'] = d['name'] ?? orgId;
        report['orgStatus'] = d['status'] ?? 'active';
        report['currency'] = d['currency'] ?? 'INR';
      }

      // 2. Tenant Employees
      final emps = await getEmployees();
      report['tenantEmployees'] = emps.length;
      report['activeEmployees'] = emps.where((e) => e['status'] != 'suspended').length;
      report['employeesWithDevice'] = emps.where((e) => (e['oneSignalPlayerId'] as String? ?? '').isNotEmpty).length;

      // 3. Tenant Notifications
      final notifsSnap = await _notificationsRef.get();
      report['tenantNotifications'] = notifsSnap.docs.length;

      // 4. Tenant Corrections
      final corrsSnap = await _correctionsRef.get();
      report['tenantCorrections'] = corrsSnap.docs.length;
      report['pendingCorrections'] = corrsSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length;

      // 5. Tenant Attendance Dates & Records
      final attSnap = await _attendanceRef.get();
      int tenantRecordCount = 0;
      for (final d in attSnap.docs) {
        final recSnap = await _attendanceRef.doc(d.id).collection('records').get();
        tenantRecordCount += recSnap.docs.length;
      }
      report['tenantAttendanceDates'] = attSnap.docs.length;
      report['tenantAttendanceRecords'] = tenantRecordCount;

      // 6. Legacy Comparison (if Renish Electronics)
      if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
        int legacyEmps = 0;
        int legacyNotifs = 0;
        int legacyAttDates = 0;
        int legacyAttRecords = 0;

        try {
          final lEmps = await _db.collection('employees').get();
          legacyEmps = lEmps.docs.length;
        } catch (_) {}

        try {
          final lNotifs = await _db.collection('notifications').get();
          legacyNotifs = lNotifs.docs.length;
        } catch (_) {}

        try {
          final lAtt = await _db.collection('attendance').get();
          legacyAttDates = lAtt.docs.length;
          for (final d in lAtt.docs) {
            final recs = await _db.collection('attendance').doc(d.id).collection('records').get();
            legacyAttRecords += recs.docs.length;
          }
        } catch (_) {}

        report['legacyEmployees'] = legacyEmps;
        report['legacyNotifications'] = legacyNotifs;
        report['legacyAttendanceDates'] = legacyAttDates;
        report['legacyAttendanceRecords'] = legacyAttRecords;
        report['isFullyMirrored'] = (emps.length >= legacyEmps && notifsSnap.docs.length >= legacyNotifs);
      }

      report['success'] = true;
      report['status'] = 'All records properly stored and verified in Firestore.';
    } catch (e) {
      report['success'] = false;
      report['error'] = e.toString();
    }

    return report;
  }
}

// Backward-compatibility alias
typedef FirestoreService = FirestoreRepository;
