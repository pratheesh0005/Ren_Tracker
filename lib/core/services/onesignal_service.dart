import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ren_tracker/core/constants/env_config.dart';

class OneSignalService {
  // Public OneSignal App ID loaded from .env
  static String get oneSignalAppId => EnvConfig.oneSignalAppId;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Call this once in main() after Firebase.initializeApp()
  static Future<void> initialize() async {
    OneSignal.initialize(oneSignalAppId);

    // Request push notification permission
    await OneSignal.Notifications.requestPermission(true);

    // Listen for foreground notifications and display them
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.notification.display();
    });

    // Save player ID to Firestore whenever subscription state changes
    OneSignal.User.pushSubscription.addObserver((state) {
      final playerId = state.current.id;
      if (playerId != null && playerId.isNotEmpty) {
        _savePlayerId(playerId);
      }
    });
  }

  /// Tag user for organization and role segmentation
  static Future<void> setTenantTags({
    required String orgId,
    required String role,
    String? empId,
  }) async {
    try {
      final tags = <String, String>{
        'orgId': orgId,
        'role': role,
      };
      if (empId != null && empId.isNotEmpty) {
        tags['empId'] = empId;
      }
      await OneSignal.User.addTags(tags);
    } catch (_) {}
  }

  /// Save OneSignal player ID linked to the logged-in user/employee
  static Future<void> _savePlayerId(String playerId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final db = FirebaseFirestore.instance;

      // Save in fcm_tokens collection
      await db.collection('fcm_tokens').doc(user.uid).set({
        'oneSignalPlayerId': playerId,
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'email': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also save in /users/{uid}
      await db.collection('users').doc(user.uid).set({
        'oneSignalPlayerId': playerId,
      }, SetOptions(merge: true));

      // Check user doc and SharedPreferences for tenant orgId and empId
      final userDoc = await db.collection('users').doc(user.uid).get();
      String? orgId = userDoc.data()?['orgId'] as String?;
      String? empId = userDoc.data()?['empId'] as String?;

      if (orgId == null || empId == null || orgId.isEmpty || empId.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        orgId ??= prefs.getString('org_id');
        empId ??= prefs.getString('emp_id');
      }

      if (orgId != null && empId != null && orgId.isNotEmpty && empId.isNotEmpty) {
        await db
            .collection('organizations')
            .doc(orgId)
            .collection('employees')
            .doc(empId)
            .set({'oneSignalPlayerId': playerId}, SetOptions(merge: true));

        if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
          await db
              .collection('employees')
              .doc(empId)
              .set({'oneSignalPlayerId': playerId}, SetOptions(merge: true));
        }

        try {
          OneSignal.login(empId);
          OneSignal.User.addAliases({'empId': empId, 'orgId': orgId});
          await setTenantTags(orgId: orgId, role: 'employee', empId: empId);
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Save player ID for a specific employee
  Future<void> saveEmployeePlayerId({
    required String orgId,
    required String empId,
  }) async {
    try {
      final playerId = OneSignal.User.pushSubscription.id;
      if (playerId == null || playerId.isEmpty) return;

      // Update in tenant employees
      await _db
          .collection('organizations')
          .doc(orgId)
          .collection('employees')
          .doc(empId)
          .set({'oneSignalPlayerId': playerId}, SetOptions(merge: true));

      // Mirror in legacy employees if Ren Tracker / Renish Electronics
      if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
        await _db
            .collection('employees')
            .doc(empId)
            .set({'oneSignalPlayerId': playerId}, SetOptions(merge: true));
      }

      // Mirror in users collection
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'oneSignalPlayerId': playerId,
          'empId': empId,
          'orgId': orgId,
        }, SetOptions(merge: true));
      }

      try {
        OneSignal.login(empId);
        OneSignal.User.addAliases({'empId': empId, 'orgId': orgId});
        await setTenantTags(orgId: orgId, role: 'employee', empId: empId);
      } catch (_) {}
    } catch (_) {}
  }

  /// Get current OneSignal player ID / Subscription ID
  String? get currentPlayerId => OneSignal.User.pushSubscription.id;

  /// Retrieve the saved OneSignal REST API Key
  Future<String?> getRestApiKey(String orgId) async {
    final envKey = EnvConfig.oneSignalRestApiKey;
    if (envKey.isNotEmpty) return envKey;

    final prefs = await SharedPreferences.getInstance();
    final localKey = prefs.getString('onesignal_rest_api_key');
    if (localKey != null && localKey.trim().isNotEmpty) {
      return localKey.trim();
    }

    try {
      final orgDoc = await _db.collection('organizations').doc(orgId).get();
      final orgKey = orgDoc.data()?['oneSignalRestApiKey'] as String?;
      if (orgKey != null && orgKey.trim().isNotEmpty) {
        return orgKey.trim();
      }
    } catch (_) {}

    try {
      final settingsDoc = await _db.collection('settings').doc('onesignal').get();
      final settingsKey = settingsDoc.data()?['restApiKey'] as String?;
      if (settingsKey != null && settingsKey.trim().isNotEmpty) {
        return settingsKey.trim();
      }
    } catch (_) {}

    return null;
  }

  /// Save OneSignal REST API Key
  Future<void> saveRestApiKey(String orgId, String key) async {
    final cleanKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('onesignal_rest_api_key', cleanKey);

    try {
      await _db.collection('organizations').doc(orgId).set({
        'oneSignalRestApiKey': cleanKey,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Dispatch notification: saves to Firestore stream AND sends OneSignal Push
  Future<Map<String, dynamic>> sendTenantNotification({
    required String title,
    required String body,
    required String orgId,
    String? adminEmail,
    String target = 'all', // 'all' or specific empId
    String? targetEmpId,
    String? targetEmpName,
    String? targetPlayerId,
    String? customRestApiKey,
  }) async {
    bool dbSaved = false;
    bool pushSent = false;
    String? pushError;

    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    final isBroadcast = target == 'all' || target == 'employees';
    final cleanEmpId = (targetEmpId ?? (isBroadcast ? '' : target)).trim();

    // 1. Resolve freshest Player ID from Firestore if target is a specific employee
    String? resolvedPlayerId = targetPlayerId?.trim();
    if (!isBroadcast && cleanEmpId.isNotEmpty) {
      if (resolvedPlayerId == null || resolvedPlayerId.isEmpty) {
        try {
          final empDoc = await _db
              .collection('organizations')
              .doc(orgId)
              .collection('employees')
              .doc(cleanEmpId)
              .get();
          resolvedPlayerId = empDoc.data()?['oneSignalPlayerId'] as String?;
        } catch (_) {}
      }
      if (resolvedPlayerId == null || resolvedPlayerId.isEmpty) {
        try {
          final uSnap = await _db
              .collection('users')
              .where('empId', isEqualTo: cleanEmpId)
              .limit(1)
              .get();
          if (uSnap.docs.isNotEmpty) {
            resolvedPlayerId = uSnap.docs.first.data()['oneSignalPlayerId'] as String?;
          }
        } catch (_) {}
      }
    }

    // 2. Save to tenant Firestore notification stream
    try {
      final notifData = {
        'title': cleanTitle,
        'message': cleanBody,
        'sentBy': adminEmail ?? 'Admin',
        'target': isBroadcast ? 'all' : cleanEmpId,
        'targetEmpId': isBroadcast ? null : cleanEmpId,
        'targetEmpName': isBroadcast ? null : targetEmpName,
        'targetPlayerId': resolvedPlayerId,
        'orgId': orgId,
        'date': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('organizations')
          .doc(orgId)
          .collection('notifications')
          .add(notifData);

      if (orgId == 'ren_tracker' || orgId == 'renish_electronics') {
        await _db.collection('notifications').add(notifData);
      }
      dbSaved = true;
    } catch (e) {
      return {'success': false, 'error': 'Failed to save notification: $e'};
    }

    // 3. Dispatch push notification via OneSignal REST API
    try {
      final effectiveApiKey = (customRestApiKey != null && customRestApiKey.trim().isNotEmpty)
          ? customRestApiKey.trim()
          : await getRestApiKey(orgId);

      if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
        final headers = {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $effectiveApiKey',
        };

        if (isBroadcast) {
          // Organization broadcast: Use filters alone (do not combine with included_segments)
          final Map<String, dynamic> broadcastPayload = {
            'app_id': oneSignalAppId,
            'headings': {'en': cleanTitle},
            'contents': {'en': cleanBody},
            'filters': [
              {'field': 'tag', 'key': 'orgId', 'relation': '=', 'value': orgId},
            ],
            'data': {
              'orgId': orgId,
              'target': 'all',
              'title': cleanTitle,
              'message': cleanBody,
            },
          };

          final res = await http.post(
            Uri.parse('https://onesignal.com/api/v1/notifications'),
            headers: headers,
            body: jsonEncode(broadcastPayload),
          );

          if (res.statusCode == 200) {
            pushSent = true;
          } else {
            pushError = 'OneSignal HTTP ${res.statusCode}: ${res.body}';
          }
        } else {
          // Specific employee: Multi-strategy push dispatch
          // Strategy A: If device Player ID / Subscription ID is known, send directly
          if (resolvedPlayerId != null && resolvedPlayerId.isNotEmpty) {
            final Map<String, dynamic> devicePayload = {
              'app_id': oneSignalAppId,
              'headings': {'en': cleanTitle},
              'contents': {'en': cleanBody},
              'include_player_ids': [resolvedPlayerId],
              'data': {
                'orgId': orgId,
                'target': cleanEmpId,
                'targetEmpId': cleanEmpId,
                'title': cleanTitle,
                'message': cleanBody,
              },
            };

            final res = await http.post(
              Uri.parse('https://onesignal.com/api/v1/notifications'),
              headers: headers,
              body: jsonEncode(devicePayload),
            );

            if (res.statusCode == 200) {
              pushSent = true;
            } else {
              pushError = 'PlayerId delivery: ${res.statusCode} ${res.body}';
            }
          }

          // Strategy B: External ID Alias (OneSignal v5 recommended external identifier)
          if (!pushSent && cleanEmpId.isNotEmpty) {
            final Map<String, dynamic> aliasPayload = {
              'app_id': oneSignalAppId,
              'headings': {'en': cleanTitle},
              'contents': {'en': cleanBody},
              'target_channel': 'push',
              'include_aliases': {
                'external_id': [cleanEmpId]
              },
              'data': {
                'orgId': orgId,
                'target': cleanEmpId,
                'targetEmpId': cleanEmpId,
                'title': cleanTitle,
                'message': cleanBody,
              },
            };

            final res = await http.post(
              Uri.parse('https://onesignal.com/api/v1/notifications'),
              headers: headers,
              body: jsonEncode(aliasPayload),
            );

            if (res.statusCode == 200) {
              pushSent = true;
            } else {
              pushError = (pushError != null ? '$pushError | ' : '') + 'Alias: ${res.body}';
            }
          }

          // Strategy C: External User IDs (Legacy OneSignal external user ID target)
          if (!pushSent && cleanEmpId.isNotEmpty) {
            final Map<String, dynamic> externalUserPayload = {
              'app_id': oneSignalAppId,
              'headings': {'en': cleanTitle},
              'contents': {'en': cleanBody},
              'include_external_user_ids': [
                cleanEmpId,
                cleanEmpId.toLowerCase(),
                cleanEmpId.toUpperCase(),
              ],
              'data': {
                'orgId': orgId,
                'target': cleanEmpId,
                'targetEmpId': cleanEmpId,
                'title': cleanTitle,
                'message': cleanBody,
              },
            };

            final res = await http.post(
              Uri.parse('https://onesignal.com/api/v1/notifications'),
              headers: headers,
              body: jsonEncode(externalUserPayload),
            );

            if (res.statusCode == 200) {
              pushSent = true;
            }
          }

          // Strategy D: Tag Filter (empId tag matching)
          if (!pushSent && cleanEmpId.isNotEmpty) {
            final Map<String, dynamic> tagPayload = {
              'app_id': oneSignalAppId,
              'headings': {'en': cleanTitle},
              'contents': {'en': cleanBody},
              'filters': [
                {'field': 'tag', 'key': 'empId', 'relation': '=', 'value': cleanEmpId},
              ],
              'data': {
                'orgId': orgId,
                'target': cleanEmpId,
                'targetEmpId': cleanEmpId,
                'title': cleanTitle,
                'message': cleanBody,
              },
            };

            final res = await http.post(
              Uri.parse('https://onesignal.com/api/v1/notifications'),
              headers: headers,
              body: jsonEncode(tagPayload),
            );

            if (res.statusCode == 200) {
              pushSent = true;
            } else {
              pushError = (pushError != null ? '$pushError | ' : '') + 'Tags: ${res.body}';
            }
          }
        }
      } else {
        pushError = 'OneSignal REST API Key not configured';
      }
    } catch (e) {
      pushError = 'Push dispatch error: $e';
    }

    return {
      'success': dbSaved,
      'dbSaved': dbSaved,
      'pushed': pushSent,
      'pushError': pushError,
    };
  }
}

