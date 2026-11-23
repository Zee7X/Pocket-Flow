// lib/features/import/domain/import_parser.dart
//
// Membaca file export dari aplikasi keuangan lain (CSV / XLSX) dan
// mengubahnya menjadi baris transaksi netral.
//
// Format yang dikenali otomatis:
// * Money Manager (Realbyte) – Excel/CSV: Period/Date, Accounts, Category,
//   Subcategory, Note, Amount/IDR, Income/Expense, Description, Currency
// * Money Lover – CSV: Id, Date, Category, Amount (negatif = keluar),
//   Currency, Note, Wallet
// * Wallet by BudgetBakers – CSV: account, category, amount, type, note, date
// * Format umum lain: kolom dipetakan dari nama header (bisa diubah manual).
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/hash.dart';
import '../../transactions/domain/transaction.dart';

enum ImportColumn {
  date,
  amount,
  income,
  expense,
  type,
  category,
  subcategory,
  note,
  account,
  currency,
}

extension ImportColumnLabel on ImportColumn {
  String get label => switch (this) {
    ImportColumn.date => 'Tanggal',
    ImportColumn.amount => 'Nominal',
    ImportColumn.income => 'Nominal masuk',
    ImportColumn.expense => 'Nominal keluar',
    ImportColumn.type => 'Jenis (masuk/keluar)',
    ImportColumn.category => 'Kategori',
    ImportColumn.subcategory => 'Subkategori',
    ImportColumn.note => 'Catatan',
    ImportColumn.account => 'Dompet / akun',
    ImportColumn.currency => 'Mata uang',
  };
}

enum ImportFormat { moneyManager, moneyLover, budgetBakers, generic }

extension ImportFormatLabel on ImportFormat {
  String get label => switch (this) {
    ImportFormat.moneyManager => 'Money Manager (Realbyte)',
    ImportFormat.moneyLover => 'Money Lover',
    ImportFormat.budgetBakers => 'Wallet by BudgetBakers',
    ImportFormat.generic => 'Format umum',
  };
}

class ImportedRow {
  final DateTime date;
  final TransactionType type;
  final int amount;
  final String? category;
  final String? note;
  final String? account;

  /// Untuk transfer: akun tujuan.
  final String? toAccount;
  final String externalRef;

  const ImportedRow({
    required this.date,
    required this.type,
    required this.amount,
    this.category,
    this.note,
    this.account,
    this.toAccount,
    required this.externalRef,
  });
}

class ImportTable {
  final List<String> headers;
  final List<List<String>> rows;
  const ImportTable(this.headers, this.rows);
}

class ImportAnalysis {
  final ImportFormat format;
  final Map<ImportColumn, int> mapping;
  final List<ImportedRow> rows;
  final int skipped;
  final List<String> warnings;

  const ImportAnalysis({
    required this.format,
    required this.mapping,
    required this.rows,
    required this.skipped,
    required this.warnings,
  });

  int get totalIncome => rows
      .where((r) => r.type == TransactionType.income)
      .fold(0, (s, r) => s + r.amount);
  int get totalExpense => rows
      .where((r) => r.type == TransactionType.expense)
      .fold(0, (s, r) => s + r.amount);
  DateTime? get firstDate => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get lastDate => rows.isEmpty
      ? null
      : rows.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
}

class ImportParser {
  static const _synonyms = <ImportColumn, List<String>>{
    ImportColumn.date: [
      'date',
      'tanggal',
      'period',
      'periode',
      'time',
      'waktu',
      'tgl',
      'datetime',
      'transaction date',
    ],
    ImportColumn.amount: [
      'amount',
      'jumlah',
      'nominal',
      'idr',
      'nilai',
      'value',
      'amount (idr)',
      'harga',
    ],
    ImportColumn.income: [
      'income amount',
      'pemasukan',
      'uang masuk',
      'credit',
      'kredit',
      'deposit',
    ],
    ImportColumn.expense: [
      'expense amount',
      'pengeluaran',
      'uang keluar',
      'debit',
      'withdrawal',
    ],
    ImportColumn.type: [
      'income/expense',
      'type',
      'tipe',
      'jenis',
      'kind',
      'transaction type',
      'in/out',
    ],
    ImportColumn.category: ['category', 'kategori', 'category name'],
    ImportColumn.subcategory: [
      'subcategory',
      'sub category',
      'subkategori',
      'sub-category',
    ],
    ImportColumn.note: [
      'note',
      'notes',
      'catatan',
      'keterangan',
      'description',
      'deskripsi',
      'memo',
      'remarks',
      'payee',
    ],
    ImportColumn.account: [
      'account',
      'accounts',
      'wallet',
      'dompet',
      'akun',
      'rekening',
      'asset',
      'source',
    ],
    ImportColumn.currency: ['currency', 'mata uang', 'ccy'],
  };

  /// Baca CSV. Pemisah (`,` `;` tab) dideteksi dari baris pertama.
  static ImportTable parseCsv(String content) {
    var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    final firstLine = text
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final delim = [
      ';',
      '\t',
      ',',
    ].reduce((a, b) => _count(firstLine, a) >= _count(firstLine, b) ? a : b);
    final rows = _splitCsv(text, delim);
    return _toTable(rows);
  }

  static ImportTable fromRows(List<List<String>> rows) => _toTable(rows);

  static ImportTable _toTable(List<List<String>> rows) {
    final nonEmpty = rows
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .toList();
    if (nonEmpty.isEmpty) return const ImportTable([], []);
    // Baris header = baris pertama (dari 10 teratas) dengan kecocokan terbanyak.
    var headerIdx = 0;
    var best = -1;
    for (var i = 0; i < nonEmpty.length && i < 10; i++) {
      final score = _guessMapping(nonEmpty[i]).length;
      if (score > best) {
        best = score;
        headerIdx = i;
      }
    }
    final headers = nonEmpty[headerIdx].map((h) => h.trim()).toList();
    return ImportTable(headers, nonEmpty.sublist(headerIdx + 1));
  }

  static int _count(String s, String ch) => ch.allMatches(s).length;

  static List<List<String>> _splitCsv(String text, String delim) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cell.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == delim) {
        row.add(cell.toString());
        cell.clear();
      } else if (c == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(c);
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static Map<ImportColumn, int> _guessMapping(List<String> headers) {
    final map = <ImportColumn, int>{};
    final lower = headers.map((h) => h.trim().toLowerCase()).toList();
    // Exact match dulu, lalu "mengandung".
    for (final exact in [true, false]) {
      for (final entry in _synonyms.entries) {
        if (map.containsKey(entry.key)) continue;
        for (var i = 0; i < lower.length; i++) {
          if (map.containsValue(i)) continue;
          final h = lower[i];
          if (h.isEmpty) continue;
          final hit = exact
              ? entry.value.contains(h)
              : entry.value.any((s) => s.length > 3 && h.contains(s));
          if (hit) {
            map[entry.key] = i;
            break;
          }
        }
      }
    }
    // Money Manager punya dua kolom "Amount"/"IDR" dan "Accounts" ganda: ambil yang pertama.
    return map;
  }

  static ImportFormat detectFormat(List<String> headers) {
    final h = headers.map((e) => e.trim().toLowerCase()).toSet();
    if (h.contains('income/expense') ||
        (h.contains('accounts') && h.contains('subcategory'))) {
      return ImportFormat.moneyManager;
    }
    if (h.contains('wallet') &&
        h.contains('category') &&
        h.contains('amount') &&
        (h.contains('id') ||
            h.contains('exclude report') ||
            h.contains('event'))) {
      return ImportFormat.moneyLover;
    }
    if (h.contains('account') && h.contains('payment_type')) {
      return ImportFormat.budgetBakers;
    }
    return ImportFormat.generic;
  }

  /// Analisis tabel. [mapping] opsional untuk menimpa tebakan otomatis.
  static ImportAnalysis analyze(
    ImportTable table, {
    Map<ImportColumn, int>? mapping,
  }) {
    final format = detectFormat(table.headers);
    final map = mapping ?? _guessMapping(table.headers);
    final warnings = <String>[];
    if (!map.containsKey(ImportColumn.date)) {
      warnings.add('Kolom tanggal tidak ditemukan.');
    }
    if (!map.containsKey(ImportColumn.amount) &&
        !map.containsKey(ImportColumn.income) &&
        !map.containsKey(ImportColumn.expense)) {
      warnings.add('Kolom nominal tidak ditemukan.');
    }
    if (warnings.isNotEmpty) {
      return ImportAnalysis(
        format: format,
        mapping: map,
        rows: const [],
        skipped: table.rows.length,
        warnings: warnings,
      );
    }

    String? cell(List<String> row, ImportColumn c) {
      final i = map[c];
      if (i == null || i >= row.length) return null;
      final v = row[i].trim();
      return v.isEmpty ? null : v;
    }

    final out = <ImportedRow>[];
    final occurrences = <String, int>{};
    var skipped = 0;
    var foreignCurrency = 0;

    for (final row in table.rows) {
      final date = parseFlexibleDate(cell(row, ImportColumn.date));
      if (date == null) {
        skipped++;
        continue;
      }
      final cur = cell(row, ImportColumn.currency)?.toUpperCase();
      if (cur != null && cur != 'IDR' && cur != 'RP') {
        foreignCurrency++;
      }

      int? signed;
      TransactionType? type;
      final amountRaw = cell(row, ImportColumn.amount);
      if (amountRaw != null) {
        signed = _signedAmount(amountRaw);
      } else {
        final inc = _signedAmount(cell(row, ImportColumn.income) ?? '');
        final exp = _signedAmount(cell(row, ImportColumn.expense) ?? '');
        if ((inc ?? 0) != 0) {
          signed = inc!.abs();
          type = TransactionType.income;
        } else if ((exp ?? 0) != 0) {
          signed = -exp!.abs();
          type = TransactionType.expense;
        }
      }
      if (signed == null || signed == 0) {
        skipped++;
        continue;
      }

      final typeRaw = cell(row, ImportColumn.type)?.toLowerCase();
      var isTransferIn = false;
      if (typeRaw != null) {
        if (typeRaw.contains('transfer')) {
          if (RegExp(r'transfer[\s-]*in\b').hasMatch(typeRaw)) {
            isTransferIn = true;
          }
          type = TransactionType.transfer;
        } else if (typeRaw.startsWith('inc') ||
            typeRaw.contains('masuk') ||
            typeRaw.contains('pemasukan') ||
            typeRaw == 'in' ||
            typeRaw.contains('income') ||
            typeRaw.contains('credit')) {
          type = TransactionType.income;
        } else if (typeRaw.startsWith('exp') ||
            typeRaw.contains('keluar') ||
            typeRaw.contains('pengeluaran') ||
            typeRaw == 'out' ||
            typeRaw.contains('expense') ||
            typeRaw.contains('debit')) {
          type = TransactionType.expense;
        }
      }
      // Money Manager mencatat transfer dua kali (Out & In): ambil sisi Out saja.
      if (isTransferIn) {
        skipped++;
        continue;
      }
      type ??= signed < 0 ? TransactionType.expense : TransactionType.income;
      // Money Lover: kategori bernama "Transfer" + nominal negatif juga transfer keluar.
      final category = cell(row, ImportColumn.category);
      final sub = cell(row, ImportColumn.subcategory);
      final account = cell(row, ImportColumn.account);
      final noteParts = [
        cell(row, ImportColumn.note),
        if (format == ImportFormat.moneyManager)
          _descriptionColumn(table.headers, row),
      ].whereType<String>().where((s) => s.isNotEmpty).toList();
      final note = noteParts.isEmpty ? null : noteParts.toSet().join(' – ');

      String? toAccount;
      if (type == TransactionType.transfer) {
        // Money Manager: kolom Category berisi akun tujuan untuk Transfer-Out.
        toAccount = category;
      }

      final amount = signed.abs();
      final baseKey =
          '${date.toIso8601String().substring(0, 10)}|${type.name}|$amount|${category ?? ''}|${note ?? ''}|${account ?? ''}';
      final n = (occurrences[baseKey] ?? 0) + 1;
      occurrences[baseKey] = n;

      out.add(
        ImportedRow(
          date: date,
          type: type,
          amount: amount,
          category: type == TransactionType.transfer
              ? null
              : (sub != null && format == ImportFormat.moneyManager
                    ? category
                    : (category ?? sub)),
          note: note,
          account: account,
          toAccount: toAccount,
          externalRef: 'import:${stableHash('$baseKey|$n')}',
        ),
      );
    }

    if (foreignCurrency > 0) {
      warnings.add(
        '$foreignCurrency baris memakai mata uang selain IDR dan diimpor apa adanya.',
      );
    }
    return ImportAnalysis(
      format: format,
      mapping: map,
      rows: out,
      skipped: skipped,
      warnings: warnings,
    );
  }

  static String? _descriptionColumn(List<String> headers, List<String> row) {
    final i = headers.indexWhere(
      (h) => h.trim().toLowerCase() == 'description',
    );
    if (i < 0 || i >= row.length) return null;
    final v = row[i].trim();
    return v.isEmpty ? null : v;
  }

  static int? _signedAmount(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    var negative = false;
    if (s.startsWith('-') || s.startsWith('(') || s.endsWith('-')) {
      negative = true;
    }
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;
    // "25000.0" dari Excel: titik dengan 1 digit = desimal.
    if (RegExp(r'^\d+\.\d{1,2}$').hasMatch(s)) s = s.split('.').first;
    final v = parseNumberToken(s);
    if (v == null) return null;
    return negative ? -v : v;
  }

  /// Tanggal dari berbagai format, termasuk serial Excel.
  static DateTime? parseFlexibleDate(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    // ISO: 2026-11-23, 2026-11-23 08:15:00, 2026-11-23T08:15:00Z
    final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
    if (iso != null) {
      return _safeDate(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }
    // dd/MM/yyyy atau MM/dd/yyyy
    final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(s);
    if (dmy != null) {
      var a = int.parse(dmy.group(1)!);
      var b = int.parse(dmy.group(2)!);
      var y = int.parse(dmy.group(3)!);
      if (y < 100) y += 2000;
      // Default format Indonesia: hari dulu. Tukar bila bulan > 12.
      if (b > 12 && a <= 12) {
        final t = a;
        a = b;
        b = t;
      }
      return _safeDate(y, b, a);
    }
    // "23 Nov 2026" / "23 November 2026"
    final named = RegExp(
      r'^(\d{1,2})\s+([A-Za-z]+)\.?\s+(\d{4})',
    ).firstMatch(s);
    if (named != null) {
      final m = _monthIndex(named.group(2)!);
      if (m != null) {
        return _safeDate(
          int.parse(named.group(3)!),
          m,
          int.parse(named.group(1)!),
        );
      }
    }
    // Serial Excel (hari sejak 1899-12-30)
    final serial = double.tryParse(s);
    if (serial != null && serial > 20000 && serial < 80000) {
      final d = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  static DateTime? _safeDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1990 || y > 2100) return null;
    return DateTime(y, m, d);
  }

  static int? _monthIndex(String name) {
    const months = [
      ['jan'],
      ['feb', 'peb'],
      ['mar'],
      ['apr'],
      ['may', 'mei'],
      ['jun'],
      ['jul'],
      ['aug', 'agu', 'ags'],
      ['sep'],
      ['oct', 'okt'],
      ['nov', 'nop'],
      ['dec', 'des'],
    ];
    final n = name.toLowerCase();
    for (var i = 0; i < months.length; i++) {
      if (months[i].any(n.startsWith)) return i + 1;
    }
    return null;
  }
}
