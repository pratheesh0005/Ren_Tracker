import 'package:intl/intl.dart';

class CurrencyHelper {
  static String format(
    num amount, {
    String symbol = '\$',
    String code = 'USD',
    int? decimalDigits,
  }) {
    final decimals = decimalDigits ?? (amount % 1 == 0 ? 0 : 2);
    try {
      final formatter = NumberFormat.currency(
        symbol: symbol,
        name: code,
        decimalDigits: decimals,
      );
      return formatter.format(amount);
    } catch (_) {
      // Fallback if locale/symbol formatting fails
      return '$symbol${amount.toStringAsFixed(decimals)}';
    }
  }
}

class TimezoneHelper {
  /// Converts a UTC DateTime to tenant-local representation based on IANA timezone name.
  /// Standard fixed-offset fallback for common timezones if timezone package is not linked.
  static DateTime toTenantTime(DateTime utcTime, String timeZone) {
    final offsetHours = _getOffsetHours(timeZone);
    return utcTime.toUtc().add(Duration(minutes: (offsetHours * 60).round()));
  }

  static String formatTenantDate(DateTime dateTime, {String format = 'yyyy-MM-dd'}) {
    return DateFormat(format).format(dateTime);
  }

  static double _getOffsetHours(String timeZone) {
    switch (timeZone) {
      case 'Asia/Kolkata':
        return 5.5;
      case 'America/New_York':
        return -5.0; // Standard (EDT is -4.0)
      case 'Europe/London':
        return 0.0; // GMT (BST is +1.0)
      case 'Asia/Singapore':
        return 8.0;
      case 'Asia/Dubai':
        return 4.0;
      case 'Asia/Riyadh':
        return 3.0;
      case 'Europe/Berlin':
      case 'Europe/Paris':
        return 1.0;
      case 'America/Toronto':
        return -5.0;
      case 'Australia/Sydney':
        return 10.0;
      case 'Asia/Kuala_Lumpur':
        return 8.0;
      case 'Asia/Tokyo':
        return 9.0;
      case 'America/Sao_Paulo':
        return -3.0;
      default:
        return 0.0;
    }
  }
}

class PhoneHelper {
  /// Standardizes international phone number into E.164 format
  static String toE164(String rawPhone, String dialCode) {
    final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
    final cleanDial = dialCode.replaceAll(RegExp(r'\D'), '');

    if (rawPhone.startsWith('+')) {
      return '+$cleanDigits';
    }

    if (cleanDigits.startsWith(cleanDial)) {
      return '+$cleanDigits';
    }

    return '+$cleanDial$cleanDigits';
  }
}

