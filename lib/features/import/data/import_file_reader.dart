// lib/features/import/data/import_file_reader.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../domain/import_parser.dart';

class ImportFileReader {
  /// Baca file CSV atau XLSX menjadi tabel.
  /// Format .xls lama (Excel 97-2003) tidak didukung: minta pengguna
  /// menyimpan ulang sebagai .xlsx atau export CSV.
  static ImportTable read(String fileName, Uint8List bytes) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) return _readXlsx(bytes);
    if (lower.endsWith('.xls')) {
      throw const FormatException(
        'File .xls (Excel lama) belum didukung. Buka di Excel/Google Sheets lalu simpan sebagai .xlsx atau .csv.',
      );
    }
    return ImportParser.parseCsv(_decodeText(bytes));
  }

  static String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  static ImportTable _readXlsx(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    // Ambil sheet dengan baris terbanyak.
    Sheet? best;
    for (final s in book.tables.values) {
      if (best == null || s.maxRows > best.maxRows) best = s;
    }
    if (best == null) return const ImportTable([], []);
    final rows = <List<String>>[];
    for (final r in best.rows) {
      rows.add([for (final c in r) _cellText(c?.value)]);
    }
    return ImportParser.fromRows(rows);
  }

  static String _cellText(CellValue? v) {
    return switch (v) {
      null => '',
      DateCellValue() => '${v.year}-${_pad2(v.month)}-${_pad2(v.day)}',
      DateTimeCellValue() => '${v.year}-${_pad2(v.month)}-${_pad2(v.day)}',
      IntCellValue() => v.value.toString(),
      DoubleCellValue() => _num(v.value),
      TextCellValue() => v.value.toString(),
      _ => v.toString(),
    };
  }

  static String _num(double d) =>
      d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  static String _pad2(int n) => n.toString().padLeft(2, '0');
}
