// lib/core/extensions/currency_extension.dart
import 'package:intl/intl.dart';

extension CurrencyExtension on int {
  /// Format integer as IDR currency.
  /// e.g. 850000 → "Rp850.000"
  String get toRupiah {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(this);
  }

  /// Compact format, e.g. 1500000 → "Rp1,5jt"
  String get toRupiahCompact {
    if (this >= 1000000000) {
      return 'Rp${(this / 1000000000).toStringAsFixed(1)}M';
    } else if (this >= 1000000) {
      return 'Rp${(this / 1000000).toStringAsFixed(1)}jt';
    } else if (this >= 1000) {
      return 'Rp${(this / 1000).toStringAsFixed(0)}rb';
    }
    return toRupiah;
  }
}
