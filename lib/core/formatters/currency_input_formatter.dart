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

    String newText = newValue.text;
    int selectionEnd = newValue.selection.end;

    // Handle user pressing backspace directly on a thousand separator dot '.'
    // e.g. "290.000" with cursor at 4 (after dot) -> delete the digit before the dot
    if (oldValue.text.length - newValue.text.length == 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.selection.baseOffset <= oldValue.text.length &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '.') {
      final dotPos = oldValue.selection.baseOffset - 1;
      if (dotPos > 0) {
        // Remove the digit before the dot
        newText = oldValue.text.substring(0, dotPos - 1) +
            oldValue.text.substring(dotPos);
        selectionEnd = dotPos - 1;
      }
    }

    // Calculate how many digits were before the cursor in the modified text
    final validEnd = selectionEnd.clamp(0, newText.length);
    final digitsBeforeCursor =
        newText.substring(0, validEnd).replaceAll(RegExp(r'[^\d]'), '').length;

    // Extract all digits
    final digitsOnly = newText.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parse to int
    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    // Find cursor position in formatted string corresponding to digitsBeforeCursor
    int newCursorPos = 0;
    int digitCount = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }
      if (digitCount <= digitsBeforeCursor) {
        newCursorPos = i + 1;
      } else {
        break;
      }
    }

    if (digitsBeforeCursor == 0) {
      newCursorPos = 0;
    }

    final safeSelectionIndex = newCursorPos.clamp(0, formatted.length);

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
