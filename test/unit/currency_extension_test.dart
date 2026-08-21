import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/core/extensions/currency_extension.dart';
import 'package:pocket_flow/core/formatters/currency_input_formatter.dart';

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

  group('CurrencyInputFormatter Tests', () {
    final formatter = CurrencyInputFormatter();

    test('realtime maps raw digits to thousand separated rupiah', () {
      final input = const TextEditingValue(
        text: '9000000',
        selection: TextSelection.collapsed(offset: 7),
      );
      final output = formatter.formatEditUpdate(
        TextEditingValue.empty,
        input,
      );

      expect(output.text, '9.000.000');
      expect(output.selection.end, 9);
    });

    test('parses thousand separated string to int accurately', () {
      expect(CurrencyInputFormatter.parse('9.000.000'), 9000000);
      expect(CurrencyInputFormatter.parse('Rp 8.500.000'), 8500000);
      expect(CurrencyInputFormatter.parse(''), 0);
      expect(CurrencyInputFormatter.parse(null), 0);
    });

    test('formats int to dot-separated string', () {
      expect(CurrencyInputFormatter.format(9000000), '9.000.000');
      expect(CurrencyInputFormatter.format(150000), '150.000');
      expect(CurrencyInputFormatter.format(0), '');
    });
  });
}
