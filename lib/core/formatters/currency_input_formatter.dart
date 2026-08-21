// lib/core/formatters/currency_input_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Automatically formats numbers as user types with Indonesian thousand separator (dot)
/// e.g. typing "9000000" outputs "9.000.000"
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Keep only digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Parse to int
    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    // Calculate cursor position from the end so backspace and inserts feel natural
    final selectionIndex = formatted.length - (newValue.text.length - newValue.selection.end);
    final safeSelectionIndex = selectionIndex.clamp(0, formatted.length);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: safeSelectionIndex),
    );
  }

  /// Helper to parse formatted rupiah string back to int
  /// e.g. "9.000.000" -> 9000000
  static int parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }

  /// Helper to format raw integer as standard dot-separated string
  /// e.g. 9000000 -> "9.000.000"
  static String format(int amount) {
    if (amount <= 0) return '';
    return NumberFormat.decimalPattern('id_ID').format(amount);
  }
}
