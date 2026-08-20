import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/core/extensions/currency_extension.dart';

void main() {
  group('CurrencyExtension Tests', () {
    test('formats standard rupiah amounts without decimals', () {
      expect(850000.toRupiah, contains('850.000'));
      expect(5300000.toRupiah, contains('5.300.000'));
      expect(13000.toRupiah, contains('13.000'));
      expect(0.toRupiah, contains('0'));
    });

    test('formats compact rupiah amounts', () {
      expect(1500000.toRupiahCompact, 'Rp1.5jt');
      expect(2000000000.toRupiahCompact, 'Rp2.0M');
      expect(50000.toRupiahCompact, 'Rp50rb');
      expect(500.toRupiahCompact, contains('500'));
    });
  });
}
