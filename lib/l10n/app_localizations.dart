import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ta'), // Tamil
  ];

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'Ren Tracker',
      'app_tagline': 'Worldwide Workforce SaaS Platform',
      'org_registration': 'Organization Registration',
      'employee_login': 'Employee Portal',
      'admin_portal': 'Admin Portal',
      'super_admin_portal': 'Super Admin Console',
      'org_name': 'Organization Name',
      'owner_name': 'Owner / Admin Name',
      'business_email': 'Business Email',
      'mobile_number': 'Mobile Number',
      'password': 'Password',
      'confirm_password': 'Confirm Password',
      'business_type': 'Business Type',
      'country': 'Country',
      'currency': 'Currency',
      'time_zone': 'Time Zone',
      'register_org': 'Register Organization',
      'send_otp': 'Send Verification Code',
      'enter_otp': 'Enter 6-Digit OTP',
      'verify_and_login': 'Verify & Sign In',
      'sign_in': 'Sign In',
      'sign_out': 'Sign Out',
      'dashboard': 'Dashboard',
      'attendance': 'Attendance',
      'employees': 'Employees',
      'salary': 'Salary',
      'notifications': 'Notifications',
      'reports': 'Reports',
      'settings': 'Settings',
      'present': 'Present',
      'absent': 'Absent',
      'half_day': 'Half Day',
      'holiday': 'Holiday',
      'effective_days': 'Effective Days',
      'earned_salary': 'Earned Salary',
      'base_salary': 'Base Salary',
      'hourly': 'Hourly',
      'daily': 'Daily',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
      'overtime': 'Overtime',
      'correction_request': 'Correction Request',
      'request_correction': 'Request Correction',
      'active': 'Active',
      'suspended': 'Suspended',
      'language': 'Language',
      'english': 'English',
      'tamil': 'தமிழ் (Tamil)',
    },
    'ta': {
      'app_title': 'ரென் ட்ராக்கர்',
      'app_tagline': 'சர்வதேச பணியாளர் மேலாண்மை தளம்',
      'org_registration': 'நிறுவன பதிவு',
      'employee_login': 'பணியாளர் உள்நுழைவு',
      'admin_portal': 'நிர்வாகி தளம்',
      'super_admin_portal': 'தலைமை நிர்வாகி கன்சோல்',
      'org_name': 'நிறுவனத்தின் பெயர்',
      'owner_name': 'உரிமையாளர் / நிர்வாகி பெயர்',
      'business_email': 'வணிக மின்னஞ்சல்',
      'mobile_number': 'கைபேசி எண்',
      'password': 'கடவுச்சொல்',
      'confirm_password': 'கடவுச்சொல்லை உறுதிசெய்',
      'business_type': 'வணிக வகை',
      'country': 'நாடு',
      'currency': 'நாணயம்',
      'time_zone': 'நேர மண்டலம்',
      'register_org': 'நிறுவனத்தை பதிவு செய்',
      'send_otp': 'சரிபார்ப்பு குறியீடு அனுப்பு',
      'enter_otp': '6-இலக்க OTP உள்ளிடவும்',
      'verify_and_login': 'சரிபார்த்து உள்நுழையவும்',
      'sign_in': 'உள்நுழைக',
      'sign_out': 'வெளியேறு',
      'dashboard': 'முகப்பு பலகை',
      'attendance': 'வருகை பதிவு',
      'employees': 'பணியாளர்கள்',
      'salary': 'சம்பளம்',
      'notifications': 'அறிவிப்புகள்',
      'reports': 'அறிக்கைகள்',
      'settings': 'அமைப்புகள்',
      'present': 'வருகை (Present)',
      'absent': 'விடுப்பு (Absent)',
      'half_day': 'அரை நாள் (Half Day)',
      'holiday': 'விடுமுறை',
      'effective_days': 'மொத்த வேலை நாட்கள்',
      'earned_salary': 'ஈட்டிய சம்பளம்',
      'base_salary': 'அடிப்படை சம்பளம்',
      'hourly': 'மணிநேர',
      'daily': 'தினசரி',
      'weekly': 'வாராந்திர',
      'monthly': 'மாதாந்திர',
      'overtime': 'கூடுதல் நேரம் (Overtime)',
      'correction_request': 'வருகை திருத்த கோரிக்கை',
      'request_correction': 'திருத்தம் கோருக',
      'active': 'செயலில்',
      'suspended': 'இடைநிறுத்தப்பட்டது',
      'language': 'மொழி',
      'english': 'English',
      'tamil': 'தமிழ் (Tamil)',
    },
  };

  String translate(String key) {
    final lang = locale.languageCode;
    return _localizedValues[lang]?[key] ?? _localizedValues['en']?[key] ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

/// Global notifier for real-time language toggling
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_locale') ?? 'en';
    _locale = Locale(langCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (!['en', 'ta'].contains(newLocale.languageCode)) return;
    _locale = newLocale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', newLocale.languageCode);
  }
}

