import 'package:flutter/services.dart';

class EnvConfig {
  static final Map<String, String> _env = {};
  static bool _initialized = false;

  /// Load and parse .env asset
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final content = await rootBundle.loadString('.env');
      for (final rawLine in content.split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eqIdx = line.indexOf('=');
        if (eqIdx > 0) {
          final key = line.substring(0, eqIdx).trim();
          var value = line.substring(eqIdx + 1).trim();
          // Remove surrounding quotes if present
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          _env[key] = value;
        }
      }
      _initialized = true;
    } catch (_) {
      // Fallbacks will be used if .env file is absent
      _initialized = true;
    }
  }

  /// Get environment value by key with optional fallback
  static String get(String key, {String fallback = ''}) {
    final val = _env[key];
    if (val != null && val.isNotEmpty) {
      return val;
    }
    return fallback;
  }

  // --- OneSignal Push Notifications ---
  static String get oneSignalAppId =>
      get('ONESIGNAL_APP_ID', fallback: '');

  static String get oneSignalRestApiKey =>
      get('ONESIGNAL_REST_API_KEY', fallback: '');

  // --- Firebase Android Client ---
  static String get firebaseApiKeyAndroid =>
      get('FIREBASE_API_KEY_ANDROID', fallback: '');

  static String get firebaseAppIdAndroid =>
      get('FIREBASE_APP_ID_ANDROID', fallback: '');

  static String get firebaseMessagingSenderId =>
      get('FIREBASE_MESSAGING_SENDER_ID', fallback: '');

  static String get firebaseProjectId =>
      get('FIREBASE_PROJECT_ID', fallback: '');

  static String get firebaseStorageBucket =>
      get('FIREBASE_STORAGE_BUCKET', fallback: '');

  // --- Firebase Web Client ---
  static String get firebaseApiKeyWeb =>
      get('FIREBASE_API_KEY_WEB', fallback: '');

  // --- Google OAuth ---
  static String get googleWebClientId =>
      get('GOOGLE_WEB_CLIENT_ID', fallback: '');

  // --- Multi-Tenant SaaS Defaults ---
  static String get defaultOrgId =>
      get('DEFAULT_ORG_ID', fallback: 'ren_tracker');
}
