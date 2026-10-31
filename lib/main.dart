import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:ren_tracker/core/constants/env_config.dart';
import 'package:ren_tracker/core/services/onesignal_service.dart';
import 'package:ren_tracker/core/theme/app_theme.dart';
import 'package:ren_tracker/features/authentication/splash_screen.dart';
import 'package:ren_tracker/firebase_options.dart';
import 'package:ren_tracker/l10n/app_localizations.dart';
import 'package:ren_tracker/routes/app_routes.dart';

final ValueNotifier<Locale> appLocaleNotifier = ValueNotifier<Locale>(const Locale('en'));

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await EnvConfig.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.init();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize OneSignal
  await OneSignalService.initialize();
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const RenTrackerApp());
}

class RenTrackerApp extends StatelessWidget {
  const RenTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocaleNotifier,
      builder: (context, currentLocale, _) {
        return MaterialApp(
          title: 'Ren Tracker',
          debugShowCheckedModeBanner: false,
          locale: currentLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          home: const SplashScreen(),
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
