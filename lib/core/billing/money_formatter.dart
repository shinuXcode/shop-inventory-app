import 'package:intl/intl.dart';

/// Formats integer paise consistently across SBILL screens.
class MoneyFormatter {
  MoneyFormatter._();

  static String format(int minor, {String currencyCode = 'INR'}) {
    final code = currencyCode.trim().isEmpty
        ? 'INR'
        : currencyCode.trim().toUpperCase();
    final locale = code == 'INR' ? 'en_IN' : 'en_US';
    return NumberFormat.currency(
      locale: locale,
      name: code,
      decimalDigits: 2,
    ).format(minor / 100);
  }
}
