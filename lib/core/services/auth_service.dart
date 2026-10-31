import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:ren_tracker/data/models/app_user.dart';
import 'package:ren_tracker/data/models/user_role.dart';
import 'package:ren_tracker/data/models/organization_model.dart';
import 'package:ren_tracker/core/utils/formatters.dart';
import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/core/services/onesignal_service.dart';

class AuthService {
  static String get defaultOrgId => EnvConfig.defaultOrgId;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: EnvConfig.googleWebClientId.isNotEmpty ? EnvConfig.googleWebClientId : null,
  );

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════════════════════════════
  //  USER PROFILE & CUSTOM CLAIMS HELPER
  // ══════════════════════════════════════════════════════════

  Future<AppUser?> getAppUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()!, uid);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser> _ensureUserRecord({
    required User user,
    UserRole? defaultRole,
    String? orgId,
    String? empId,
    String? name,
  }) async {
    final userRef = _db.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    // Check Custom Claims first (cryptographically signed by Firebase Auth)
    final tokenResult = await user.getIdTokenResult(true);
    final claimRole = tokenResult.claims?['role'] as String?;
    final claimOrgId = tokenResult.claims?['orgId'] as String?;
    final claimEmpId = tokenResult.claims?['empId'] as String?;

    if (userDoc.exists) {
      final data = userDoc.data()!;
      var appUser = AppUser.fromMap(data, user.uid);

      // Upgrade role from custom claim if present
      if (claimRole != null) {
        appUser = appUser.copyWith(
          role: UserRole.fromString(claimRole),
          orgId: claimOrgId ?? appUser.orgId,
          empId: claimEmpId ?? appUser.empId,
        );
      }

      // Check if email matches an organization's adminEmail or ownerUid
      if (!appUser.isSuperAdmin && (appUser.orgId == null || appUser.orgId!.isEmpty)) {
        try {
          final orgSnap = await _db
              .collection('organizations')
              .where('adminEmail', isEqualTo: user.email?.toLowerCase().trim())
              .limit(1)
              .get();
          if (orgSnap.docs.isNotEmpty) {
            final foundOrgId = orgSnap.docs.first.id;
            await userRef.update({'orgId': foundOrgId, 'role': 'admin'});
            appUser = appUser.copyWith(orgId: foundOrgId, role: UserRole.admin);
          }
        } catch (_) {}
      }

      return appUser;
    }

    // Provision new user record
    UserRole roleToAssign = defaultRole ?? UserRole.employee;
    if (claimRole != null) {
      roleToAssign = UserRole.fromString(claimRole);
    }

    final newAppUser = AppUser(
      uid: user.uid,
      email: user.email?.toLowerCase().trim(),
      phone: user.phoneNumber,
      name: name ?? user.displayName ?? (user.email != null ? user.email!.split('@').first : 'User'),
      role: roleToAssign,
      orgId: claimOrgId ?? orgId,
      empId: claimEmpId ?? empId,
      isSuspended: false,
    );

    await userRef.set(newAppUser.toMap(), SetOptions(merge: true));
    return newAppUser;
  }

  // ══════════════════════════════════════════════════════════
  //  GLOBAL ORGANIZATION REGISTRATION
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> registerOrganization({
    required String orgName,
    required String ownerName,
    required String email,
    required String password,
    required String country,
    required String countryCode,
    required String phone,
    required String businessType,
    required String currency,
    required String currencySymbol,
    required String timeZone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Generate unique URL-safe orgId slug
    String slug = orgName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.length < 3) slug = 'org';

    String finalOrgId = slug;
    try {
      final doc = await _db.collection('organizations').doc(finalOrgId).get();
      if (doc.exists) {
        finalOrgId = '$slug-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      }
    } catch (_) {}

    final formattedPhone = PhoneHelper.toE164(phone, countryCode);

    // 2. Create owner user in Firebase Auth
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'OrgRegistration_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCred = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final uid = userCred.user!.uid;
      await userCred.user!.updateDisplayName(ownerName.trim());
      await secondaryApp.delete();
      secondaryApp = null;

      // Automatically sign in on primary auth FIRST so that Firestore writes are authenticated as the new owner
      await _auth.signInWithEmailAndPassword(email: cleanEmail, password: password);

      // 3. Create Organization Document with full worldwide settings
      final orgModel = OrganizationModel(
        orgId: finalOrgId,
        name: orgName.trim(),
        country: country,
        countryCode: countryCode,
        currency: currency,
        currencySymbol: currencySymbol,
        timeZone: timeZone,
        businessType: businessType,
        adminEmail: cleanEmail,
        ownerUid: uid,
        status: 'active',
      );

      await _db.collection('organizations').doc(finalOrgId).set(orgModel.toMap(), SetOptions(merge: true));

      // 4. Create User Document
      final appUser = AppUser(
        uid: uid,
        email: cleanEmail,
        name: ownerName.trim(),
        phone: formattedPhone,
        role: UserRole.admin,
        orgId: finalOrgId,
        isSuspended: false,
      );
      await _db.collection('users').doc(uid).set(appUser.toMap(), SetOptions(merge: true));

      // 5. Add to members subcollection
      await _db
          .collection('organizations')
          .doc(finalOrgId)
          .collection('members')
          .doc(uid)
          .set({
        'uid': uid,
        'email': cleanEmail,
        'name': ownerName.trim(),
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', 'admin');
      await prefs.setString('user_uid', uid);
      await prefs.setString('org_id', finalOrgId);

      return {'success': true, 'orgId': finalOrgId, 'user': appUser};
    } on FirebaseAuthException catch (e) {
      return {'error': _authErrorMsg(e.code, e.message)};
    } catch (e) {
      return {'error': 'Registration failed: $e'};
    } finally {
      await secondaryApp?.delete();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  ADMIN & SUPER ADMIN — Email + Password Login
  // ══════════════════════════════════════════════════════════

  Future<String?> signInAdmin(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) return 'Login failed. User not found.';

      final appUser = await _ensureUserRecord(user: user, defaultRole: UserRole.admin);

      if (appUser.isSuspended) {
        await _auth.signOut();
        return 'Your account has been suspended. Please contact platform support.';
      }

      if (appUser.isEmployee) {
        await _auth.signOut();
        return 'Access denied. This portal is for Administrators only.';
      }

      await _savePushTokens(user.uid, null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', appUser.role.toValue());
      await prefs.setString('user_uid', appUser.uid);
      if (appUser.orgId != null) {
        await prefs.setString('org_id', appUser.orgId!);
      }

      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _authErrorMsg(e.code);
    } catch (e) {
      return 'Authentication failed: $e';
    }
  }

  // ══════════════════════════════════════════════════════════
  //  EMPLOYEE — International Phone OTP Authentication (E.164)
  // ══════════════════════════════════════════════════════════

  Future<void> sendOtp({
    required String phone,
    required String dialCode,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential credential)? onAutoVerified,
  }) async {
    try {
      final formattedPhone = PhoneHelper.toE164(phone, dialCode);

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_authErrorMsg(e.code, e.message));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Failed to send OTP: $e');
    }
  }

  Future<Map<String, dynamic>> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
    required String rawPhone,
    required String dialCode,
    String? selectedOrgId,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) {
        return {'error': 'Verification failed. Could not sign in.'};
      }

      final formattedPhone = PhoneHelper.toE164(rawPhone, dialCode);

      // Locate employee record by international phone
      final empData = await _findEmployeeByInternationalPhone(formattedPhone, targetOrgId: selectedOrgId);
      if (empData == null) {
        await _auth.signOut();
        return {
          'error': 'No employee record found for mobile $formattedPhone.\nPlease contact your organization administrator.',
        };
      }

      final assignedOrg = empData['orgId'] as String? ?? defaultOrgId;
      final appUser = await _ensureUserRecord(
        user: user,
        defaultRole: UserRole.employee,
        orgId: assignedOrg,
        empId: empData['id'],
        name: empData['name'],
      );

      if (appUser.isSuspended) {
        await _auth.signOut();
        return {'error': 'Your account has been suspended. Please contact admin.'};
      }

      await _savePushTokens(user.uid, empData['id'], assignedOrg);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', 'employee');
      await prefs.setString('emp_id', empData['id'] ?? '');
      await prefs.setString('emp_name', empData['name'] ?? '');
      await prefs.setString('org_id', assignedOrg);
      await prefs.setString('login_type', 'employee_otp');

      return {
        'user': appUser,
        'empData': empData,
        'isEmployee': true,
      };
    } on FirebaseAuthException catch (e) {
      return {'error': _authErrorMsg(e.code, e.message)};
    } catch (e) {
      return {'error': 'Verification failed: $e'};
    }
  }

  Future<Map<String, dynamic>?> _findEmployeeByInternationalPhone(String fullPhone, {String? targetOrgId}) async {
    final cleanInput = fullPhone.replaceAll(RegExp(r'\D'), '');

    // 1. If target org specified, check that org's employee subcollection directly
    if (targetOrgId != null && targetOrgId.isNotEmpty) {
      try {
        final snap = await _db.collection('organizations').doc(targetOrgId).collection('employees').get();
        for (final doc in snap.docs) {
          final stored = (doc.data()['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
          if (stored.isNotEmpty && (cleanInput.endsWith(stored) || stored.endsWith(cleanInput))) {
            return {'id': doc.id, 'orgId': targetOrgId, ...doc.data()};
          }
        }
      } catch (_) {}
    }

    // 2. Check default tenant (ren_tracker)
    try {
      final orgSnap = await _db
          .collection('organizations')
          .doc(defaultOrgId)
          .collection('employees')
          .get();
      for (final doc in orgSnap.docs) {
        final stored = (doc.data()['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (stored.isNotEmpty && (cleanInput.endsWith(stored) || stored.endsWith(cleanInput))) {
          return {'id': doc.id, 'orgId': defaultOrgId, ...doc.data()};
        }
      }
    } catch (_) {}

    // 3. Scan across all organizations
    try {
      final allOrgs = await _db.collection('organizations').get();
      for (final orgDoc in allOrgs.docs) {
        if (orgDoc.id == defaultOrgId) continue;
        final subSnap = await orgDoc.reference.collection('employees').get();
        for (final doc in subSnap.docs) {
          final stored = (doc.data()['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
          if (stored.isNotEmpty && (cleanInput.endsWith(stored) || stored.endsWith(cleanInput))) {
            return {'id': doc.id, 'orgId': orgDoc.id, ...doc.data()};
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // ══════════════════════════════════════════════════════════
  //  EMPLOYEE PROVISIONING & EMAIL + PASSWORD AUTH
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> createEmployeeAccount({
    required String email,
    required String password,
    required String name,
    required String orgId,
    required String empId,
    String? phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanOrgId = orgId.trim().toLowerCase();
    final cleanEmpId = empId.trim().toUpperCase();

    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'EmpProvisioning_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      String uid;
      try {
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password.trim(),
        );
        uid = cred.user!.uid;
        await cred.user!.updateDisplayName(name.trim());
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          final existing = await _db
              .collection('users')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();
          if (existing.docs.isNotEmpty) {
            uid = existing.docs.first.id;
          } else {
            return {'success': true, 'email': cleanEmail, 'existing': true};
          }
        } else {
          return {'error': _authErrorMsg(e.code, e.message)};
        }
      }

      final appUser = AppUser(
        uid: uid,
        email: cleanEmail,
        name: name.trim(),
        phone: phone ?? '',
        role: UserRole.employee,
        orgId: cleanOrgId,
        empId: cleanEmpId,
        isSuspended: false,
      );

      await _db.collection('users').doc(uid).set(appUser.toMap(), SetOptions(merge: true));

      await _db
          .collection('organizations')
          .doc(cleanOrgId)
          .collection('members')
          .doc(uid)
          .set({
        'uid': uid,
        'email': cleanEmail,
        'name': name.trim(),
        'role': 'employee',
        'empId': cleanEmpId,
        'orgId': cleanOrgId,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return {'success': true, 'uid': uid, 'email': cleanEmail};
    } catch (e) {
      return {'error': 'Failed to provision employee auth credentials: $e'};
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<Map<String, dynamic>> signInEmployeeWithEmail({
    required String email,
    required String password,
    String? selectedOrgId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || password.isEmpty) {
      return {'error': 'Please enter your employee email and password.'};
    }

    try {
      User? user;
      try {
        final cred = await _auth.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        user = cred.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // Check if employee can be auto-registered with provided credentials on first login
          try {
            final newCred = await _auth.createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
            user = newCred.user;
          } on FirebaseAuthException catch (signUpErr) {
            if (signUpErr.code == 'email-already-in-use') {
              return {'error': 'Incorrect password. Please verify your credentials or contact admin.'};
            }
            return {'error': _authErrorMsg(signUpErr.code, signUpErr.message)};
          }
        } else {
          return {'error': _authErrorMsg(e.code, e.message)};
        }
      }

      if (user == null) {
        return {'error': 'Login failed. User could not be authenticated.'};
      }

      // Check if suspended
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()?['status'] == 'suspended') {
        await _auth.signOut();
        return {'error': 'Your account has been suspended. Please contact admin.'};
      }

      // Locate employee record by email
      Map<String, dynamic>? empData;
      String? assignedOrg = userDoc.data()?['orgId'] as String?;
      String? empId = userDoc.data()?['empId'] as String?;

      if (assignedOrg != null && assignedOrg.isNotEmpty && empId != null && empId.isNotEmpty) {
        try {
          final doc = await _db
              .collection('organizations')
              .doc(assignedOrg)
              .collection('employees')
              .doc(empId)
              .get();
          if (doc.exists) {
            empData = {'id': doc.id, 'orgId': assignedOrg, ...doc.data()!};
          }
        } catch (_) {}
      }

      if (empData == null) {
        empData = await _findEmployeeByEmail(cleanEmail, targetOrgId: selectedOrgId);
      }

      if (empData == null) {
        final userRole = userDoc.data()?['role'] as String?;
        if (userRole == 'admin' || userRole == 'super_admin') {
          return {'isAdminRedirect': true, 'role': userRole};
        }
        await _auth.signOut();
        return {
          'error': 'No active employee record found for email $cleanEmail.\nPlease contact your company administrator to verify your employee profile.',
        };
      }

      final finalOrg = empData['orgId'] as String? ?? defaultOrgId;
      final finalEmpId = empData['id'] as String;

      final appUser = await _ensureUserRecord(
        user: user,
        defaultRole: UserRole.employee,
        orgId: finalOrg,
        empId: finalEmpId,
        name: empData['name'],
      );

      // Link UID to employee document
      try {
        await _db
            .collection('organizations')
            .doc(finalOrg)
            .collection('employees')
            .doc(finalEmpId)
            .set({'linkedUid': user.uid, 'email': cleanEmail}, SetOptions(merge: true));
      } catch (_) {}

      await _savePushTokens(user.uid, finalEmpId, finalOrg);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', 'employee');
      await prefs.setString('emp_id', finalEmpId);
      await prefs.setString('emp_name', empData['name'] ?? '');
      await prefs.setString('org_id', finalOrg);
      await prefs.setString('login_type', 'employee_email');

      return {
        'user': appUser,
        'empData': empData,
        'isEmployee': true,
      };
    } on FirebaseAuthException catch (e) {
      return {'error': _authErrorMsg(e.code, e.message)};
    } catch (e) {
      return {'error': 'Employee login failed: $e'};
    }
  }

  Future<Map<String, dynamic>> signInEmployeeWithGoogle({String? selectedOrgId}) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'cancelled': true};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;
      if (user == null) {
        return {'error': 'Google authentication failed.'};
      }

      final cleanEmail = (user.email ?? '').trim().toLowerCase();
      if (cleanEmail.isEmpty) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return {'error': 'No email address found on this Google account.'};
      }

      // 1. Locate employee record by email or linkedUid
      Map<String, dynamic>? empData;
      String? matchedOrgId;

      // Check existing user profile first
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final role = data['role'] as String?;
        final org = data['orgId'] as String?;
        final empId = data['empId'] as String?;
        if (role == 'employee' && org != null && empId != null) {
          try {
            final empDoc = await _db.collection('organizations').doc(org).collection('employees').doc(empId).get();
            if (empDoc.exists) {
              empData = {'id': empDoc.id, 'orgId': org, ...empDoc.data()!};
              matchedOrgId = org;
            }
          } catch (_) {}
        }
      }

      // Search by email across target organization or all tenant directories
      if (empData == null) {
        empData = await _findEmployeeByEmail(cleanEmail, targetOrgId: selectedOrgId);
        if (empData != null) {
          matchedOrgId = empData['orgId'] as String?;
        }
      }

      // Search by linkedUid in employees collection
      if (empData == null) {
        try {
          final querySnap = await _db
              .collectionGroup('employees')
              .where('linkedUid', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            final doc = querySnap.docs.first;
            final parentOrg = doc.reference.parent.parent?.id ?? defaultOrgId;
            empData = {'id': doc.id, 'orgId': parentOrg, ...doc.data()};
            matchedOrgId = parentOrg;
          }
        } catch (_) {}
      }

      // 2. CRITICAL: If that account is not present, reject as invalid account!
      if (empData == null) {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return {
          'error': 'Invalid account: $cleanEmail is not registered as an employee in any organization. Please contact your administrator.'
        };
      }

      // 3. Check suspension
      if (empData['status'] == 'suspended') {
        await _auth.signOut();
        await _googleSignIn.signOut();
        return {'error': 'Your account has been suspended. Please contact your organization administrator.'};
      }

      final finalEmpId = (empData['id'] ?? empData['empId']) as String;
      final finalOrg = matchedOrgId ?? (empData['orgId'] as String? ?? defaultOrgId);

      // Link UID to employee document
      try {
        await _db.collection('organizations').doc(finalOrg).collection('employees').doc(finalEmpId).set({
          'linkedUid': user.uid,
          'email': cleanEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // Update /users/{uid} document
      final appUser = AppUser(
        uid: user.uid,
        email: cleanEmail,
        name: empData['name'] as String? ?? user.displayName ?? 'Employee',
        phone: empData['phone'] as String? ?? user.phoneNumber ?? '',
        role: UserRole.employee,
        orgId: finalOrg,
        empId: finalEmpId,
        isSuspended: false,
      );
      await _db.collection('users').doc(user.uid).set(appUser.toMap(), SetOptions(merge: true));

      await _savePushTokens(user.uid, finalEmpId, finalOrg);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', 'employee');
      await prefs.setString('emp_id', finalEmpId);
      await prefs.setString('emp_name', empData['name'] ?? '');
      await prefs.setString('org_id', finalOrg);
      await prefs.setString('login_type', 'employee_google');

      return {
        'user': appUser,
        'empData': empData,
        'isEmployee': true,
      };
    } catch (e) {
      try {
        await _auth.signOut();
        await _googleSignIn.signOut();
      } catch (_) {}
      return {'error': 'Google Sign-In failed: $e'};
    }
  }

  Future<Map<String, dynamic>?> _findEmployeeByEmail(String email, {String? targetOrgId}) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. If target org specified
    if (targetOrgId != null && targetOrgId.isNotEmpty) {
      try {
        final querySnap = await _db
            .collection('organizations')
            .doc(targetOrgId)
            .collection('employees')
            .where('email', isEqualTo: cleanEmail)
            .limit(1)
            .get();
        if (querySnap.docs.isNotEmpty) {
          final doc = querySnap.docs.first;
          return {'id': doc.id, 'orgId': targetOrgId, ...doc.data()};
        }
      } catch (_) {}

      try {
        final snap = await _db.collection('organizations').doc(targetOrgId).collection('employees').get();
        for (final doc in snap.docs) {
          if ((doc.data()['email'] as String? ?? '').toLowerCase().trim() == cleanEmail) {
            return {'id': doc.id, 'orgId': targetOrgId, ...doc.data()};
          }
        }
      } catch (_) {}
    }

    // 2. Check default tenant (ren_tracker)
    try {
      final querySnap = await _db
          .collection('organizations')
          .doc(defaultOrgId)
          .collection('employees')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();
      if (querySnap.docs.isNotEmpty) {
        final doc = querySnap.docs.first;
        return {'id': doc.id, 'orgId': defaultOrgId, ...doc.data()};
      }
    } catch (_) {}

    // 3. Scan across all organizations
    try {
      final allOrgs = await _db.collection('organizations').get();
      for (final orgDoc in allOrgs.docs) {
        if (orgDoc.id == defaultOrgId) continue;
        try {
          final querySnap = await orgDoc.reference
              .collection('employees')
              .where('email', isEqualTo: cleanEmail)
              .limit(1)
              .get();
          if (querySnap.docs.isNotEmpty) {
            final doc = querySnap.docs.first;
            return {'id': doc.id, 'orgId': orgDoc.id, ...doc.data()};
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4. Fallback to legacy root collection
    try {
      final snap = await _db.collection('employees').where('email', isEqualTo: cleanEmail).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first;
        return {'id': doc.id, 'orgId': defaultOrgId, ...doc.data()};
      }
    } catch (_) {}

    return null;
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMsg(e.code, e.message);
    } catch (e) {
      return e.toString();
    }
  }

  // ══════════════════════════════════════════════════════════
  //  GOOGLE SIGN-IN
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await _auth.signInWithCredential(credential);
      final User? user = userCred.user;
      if (user == null) return null;

      final appUser = await _ensureUserRecord(user: user);

      if (appUser.isSuspended) {
        await _auth.signOut();
        return {'error': 'Your account has been suspended.'};
      }

      await _savePushTokens(user.uid, appUser.empId, appUser.orgId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('user_role', appUser.role.toValue());
      await prefs.setString('user_uid', appUser.uid);
      if (appUser.orgId != null) {
        await prefs.setString('org_id', appUser.orgId!);
      }

      if (appUser.isSuperAdmin) {
        return {'isSuperAdmin': true, 'user': appUser};
      } else if (appUser.isAdmin) {
        return {'isAdmin': true, 'user': appUser};
      }

      return {
        'user': appUser,
        'isEmployee': appUser.isEmployee,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ══════════════════════════════════════════════════════════
  //  SUPER ADMIN MANAGEMENT CAPABILITIES
  // ══════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getOrganizations() async {
    try {
      final snap = await _db.collection('organizations').orderBy('name').get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> createOrganization({
    required String orgId,
    required String name,
    required String adminEmail,
    String? adminPassword,
    String? adminName,
    String? country,
    String? currency,
    String? timeZone,
  }) async {
    final cleanOrgId = orgId.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final orgModel = OrganizationModel(
      orgId: cleanOrgId,
      name: name.trim(),
      adminEmail: adminEmail.trim().toLowerCase(),
      country: country ?? 'IN',
      currency: currency ?? 'INR',
      timeZone: timeZone ?? 'Asia/Kolkata',
      status: 'active',
    );
    await _db.collection('organizations').doc(cleanOrgId).set(orgModel.toMap(), SetOptions(merge: true));
  }

  Future<String?> createAdminAccount({
    required String email,
    required String password,
    required String name,
    required String orgId,
  }) async {
    final cleanOrgId = orgId.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: 'AdminProvisioning_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final uid = cred.user!.uid;
      await cred.user!.updateDisplayName(name.trim());

      final appUser = AppUser(
        uid: uid,
        email: email.trim(),
        name: name.trim(),
        role: UserRole.admin,
        orgId: cleanOrgId,
        isSuspended: false,
      );
      await _db.collection('users').doc(uid).set(appUser.toMap(), SetOptions(merge: true));

      await _db
          .collection('organizations')
          .doc(cleanOrgId)
          .collection('members')
          .doc(uid)
          .set({
        'uid': uid,
        'email': email.trim(),
        'name': name.trim(),
        'role': 'admin',
        'orgId': cleanOrgId,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMsg(e.code, e.message);
    } catch (e) {
      return 'Failed to provision admin: $e';
    } finally {
      await secondaryApp?.delete();
    }
  }

  Future<void> toggleOrganizationSuspension({
    required String orgId,
    required bool suspend,
  }) async {
    final status = suspend ? 'suspended' : 'active';
    await _db.collection('organizations').doc(orgId).update({
      'status': status,
      'suspendedAt': suspend ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<void> toggleUserSuspension({
    required String uid,
    required bool suspend,
  }) async {
    final status = suspend ? 'suspended' : 'active';
    await _db.collection('users').doc(uid).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>> getPlatformStats() async {
    try {
      final orgsSnap = await _db.collection('organizations').get();
      final usersSnap = await _db.collection('users').get();
      int superAdmins = 0;
      int admins = 0;
      int employees = 0;

      for (final doc in usersSnap.docs) {
        final role = doc.data()['role'] as String?;
        if (role == 'super_admin') {
          superAdmins++;
        } else if (role == 'admin') {
          admins++;
        } else {
          employees++;
        }
      }

      return {
        'totalOrgs': orgsSnap.docs.length,
        'totalUsers': usersSnap.docs.length,
        'superAdmins': superAdmins,
        'admins': admins,
        'employees': employees,
      };
    } catch (_) {
      return {'totalOrgs': 0, 'totalUsers': 0, 'superAdmins': 0, 'admins': 0, 'employees': 0};
    }
  }

  // ══════════════════════════════════════════════════════════
  //  PUSH TOKENS
  // ══════════════════════════════════════════════════════════

  Future<void> _savePushTokens(String uid, String? empId, [String? orgId]) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final fcmToken = await messaging.getToken();
      final oneSignalId = OneSignal.User.pushSubscription.id;
      final tokenData = {
        'fcmToken': fcmToken ?? '',
        'oneSignalPlayerId': oneSignalId ?? '',
        'phone': currentUser?.phoneNumber ?? '',
        'empId': empId ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _db.collection('fcm_tokens').doc(uid).set(tokenData, SetOptions(merge: true));
      await _db.collection('users').doc(uid).set({
        'oneSignalPlayerId': oneSignalId ?? '',
        if (empId != null && empId.isNotEmpty) 'empId': empId,
        if (orgId != null && orgId.isNotEmpty) 'orgId': orgId,
      }, SetOptions(merge: true));

      if (empId != null && empId.isNotEmpty) {
        try {
          OneSignal.login(empId);
          OneSignal.User.addAliases({'empId': empId, if (orgId != null) 'orgId': orgId});
        } catch (_) {}
      }

      if (orgId != null && empId != null && orgId.isNotEmpty && empId.isNotEmpty) {
        await OneSignalService.setTenantTags(
          orgId: orgId,
          role: 'employee',
          empId: empId,
        );
        await OneSignalService().saveEmployeePlayerId(
          orgId: orgId,
          empId: empId,
        );
      }
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════
  //  SESSION RESTORE
  // ══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!loggedIn) return null;

    final user = _auth.currentUser;
    if (user != null) {
      final appUser = await _ensureUserRecord(user: user);

      if (appUser.isSuspended) {
        await signOut();
        return null;
      }

      if (appUser.isSuperAdmin) {
        return {'isSuperAdmin': true, 'user': appUser};
      } else if (appUser.isAdmin) {
        return {'isAdmin': true, 'user': appUser};
      } else {
        // Employee
        Map<String, dynamic>? empData;
        final org = appUser.orgId ?? defaultOrgId;
        if (appUser.empId != null && appUser.empId!.isNotEmpty) {
          try {
            final doc = await _db.collection('organizations').doc(org).collection('employees').doc(appUser.empId).get();
            if (doc.exists) {
              empData = {'id': doc.id, 'orgId': org, ...doc.data()!};
            }
          } catch (_) {}
        }
        return {'isEmployee': true, 'user': appUser, 'empData': empData};
      }
    }

    return null;
  }

  // ══════════════════════════════════════════════════════════
  //  SIGN OUT
  // ══════════════════════════════════════════════════════════

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try { await OneSignal.logout(); } catch (_) {}
    try { await _googleSignIn.signOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
  }

  String _authErrorMsg(String code, [String? rawMessage]) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please enter the correct 6-digit code.';
      case 'session-expired':
        return 'OTP has expired. Please request a new code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for today.';
      default:
        return rawMessage != null && rawMessage.isNotEmpty
            ? rawMessage
            : 'Authentication failed ($code).';
    }
  }
}

