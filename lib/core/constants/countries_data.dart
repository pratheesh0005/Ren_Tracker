class CountryInfo {
  final String name;
  final String code; // ISO 3166-1 alpha-2 (e.g. 'US', 'IN')
  final String flag;
  final String dialCode; // e.g. '+1', '+91'
  final String currencyCode; // ISO 4217 (e.g. 'USD', 'INR')
  final String currencySymbol; // e.g. '$', '₹'
  final String timeZone; // IANA (e.g. 'America/New_York')
  final List<int> defaultWorkingDays; // 1 = Monday ... 7 = Sunday

  const CountryInfo({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.timeZone,
    required this.defaultWorkingDays,
  });
}

class CountriesData {
  static const List<CountryInfo> all = [
    CountryInfo(
      name: 'India',
      code: 'IN',
      flag: '🇮🇳',
      dialCode: '+91',
      currencyCode: 'INR',
      currencySymbol: '₹',
      timeZone: 'Asia/Kolkata',
      defaultWorkingDays: [1, 2, 3, 4, 5, 6],
    ),
    CountryInfo(
      name: 'United States',
      code: 'US',
      flag: '🇺🇸',
      dialCode: '+1',
      currencyCode: 'USD',
      currencySymbol: '\$',
      timeZone: 'America/New_York',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'United Kingdom',
      code: 'GB',
      flag: '🇬🇧',
      dialCode: '+44',
      currencyCode: 'GBP',
      currencySymbol: '£',
      timeZone: 'Europe/London',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Singapore',
      code: 'SG',
      flag: '🇸🇬',
      dialCode: '+65',
      currencyCode: 'SGD',
      currencySymbol: 'S\$',
      timeZone: 'Asia/Singapore',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'United Arab Emirates',
      code: 'AE',
      flag: '🇦🇪',
      dialCode: '+971',
      currencyCode: 'AED',
      currencySymbol: 'AED',
      timeZone: 'Asia/Dubai',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Saudi Arabia',
      code: 'SA',
      flag: '🇸🇦',
      dialCode: '+966',
      currencyCode: 'SAR',
      currencySymbol: 'SAR',
      timeZone: 'Asia/Riyadh',
      defaultWorkingDays: [7, 1, 2, 3, 4], // Sun-Thu
    ),
    CountryInfo(
      name: 'Germany',
      code: 'DE',
      flag: '🇩🇪',
      dialCode: '+49',
      currencyCode: 'EUR',
      currencySymbol: '€',
      timeZone: 'Europe/Berlin',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Canada',
      code: 'CA',
      flag: '🇨🇦',
      dialCode: '+1',
      currencyCode: 'CAD',
      currencySymbol: 'C\$',
      timeZone: 'America/Toronto',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Australia',
      code: 'AU',
      flag: '🇦🇺',
      dialCode: '+61',
      currencyCode: 'AUD',
      currencySymbol: 'A\$',
      timeZone: 'Australia/Sydney',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Malaysia',
      code: 'MY',
      flag: '🇲🇾',
      dialCode: '+60',
      currencyCode: 'MYR',
      currencySymbol: 'RM',
      timeZone: 'Asia/Kuala_Lumpur',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'Japan',
      code: 'JP',
      flag: '🇯🇵',
      dialCode: '+81',
      currencyCode: 'JPY',
      currencySymbol: '¥',
      timeZone: 'Asia/Tokyo',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
    CountryInfo(
      name: 'France',
      code: 'FR',
      flag: '🇫🇷',
      dialCode: '+33',
      currencyCode: 'EUR',
      currencySymbol: '€',
      timeZone: 'Europe/Paris',
      defaultWorkingDays: [1, 2, 3, 4, 5],
    ),
  ];

  static CountryInfo get defaultCountry => all.first; // India by default for backward compatibility

  static CountryInfo findByCode(String? code) {
    if (code == null) return defaultCountry;
    return all.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => defaultCountry,
    );
  }

  static CountryInfo findByDialCode(String? dialCode) {
    if (dialCode == null) return defaultCountry;
    final clean = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    return all.firstWhere(
      (c) => c.dialCode == clean,
      orElse: () => defaultCountry,
    );
  }
}
