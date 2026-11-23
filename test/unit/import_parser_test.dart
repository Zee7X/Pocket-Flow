import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/features/import/domain/import_parser.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';

void main() {
  test('Money Lover CSV (semicolon, nominal negatif = keluar)', () {
    const csv = '''Id;Date;Category;Amount;Currency;Note;Wallet
1;23/11/2026;Food & Beverage;-25000;IDR;Bakso;Cash
2;22/11/2026;Salary;8500000;IDR;Gaji;BCA
3;21/11/2026;Food & Beverage;-25000;IDR;Bakso;Cash
''';
    final t = ImportParser.parseCsv(csv);
    final a = ImportParser.analyze(t);
    expect(a.format, ImportFormat.moneyLover);
    expect(a.rows.length, 3);
    expect(a.rows.first.type, TransactionType.expense);
    expect(a.rows.first.amount, 25000);
    expect(a.rows.first.date, DateTime(2026, 11, 23));
    expect(a.rows.first.account, 'Cash');
    expect(a.rows[1].type, TransactionType.income);
    expect(a.totalExpense, 50000);
    // Baris berbeda tanggal -> ref berbeda
    expect(a.rows[0].externalRef == a.rows[2].externalRef, isFalse);
  });

  test('Money Manager: Income/Expense + transfer hanya sisi Out', () {
    final t = ImportParser.fromRows([
      ['Period', 'Accounts', 'Category', 'Subcategory', 'Note', 'IDR', 'Income/Expense', 'Description', 'Amount', 'Currency'],
      ['2026-11-20 08:15:00', 'Cash', 'Food', 'Lunch', 'Nasi padang', '35000', 'Exp.', '', '35000', 'IDR'],
      ['2026-11-20 09:00:00', 'Bank BCA', 'GoPay', '', '', '100000', 'Transfer-Out', '', '100000', 'IDR'],
      ['2026-11-20 09:00:00', 'GoPay', 'Bank BCA', '', '', '100000', 'Transfer-In', '', '100000', 'IDR'],
      ['2026-11-01 07:00:00', 'Bank BCA', 'Salary', '', 'Gaji', '8500000', 'Income', '', '8500000', 'IDR'],
    ]);
    final a = ImportParser.analyze(t);
    expect(a.format, ImportFormat.moneyManager);
    expect(a.rows.length, 3);
    expect(a.skipped, 1);
    expect(a.rows[0].type, TransactionType.expense);
    expect(a.rows[0].category, 'Food');
    expect(a.rows[1].type, TransactionType.transfer);
    expect(a.rows[1].account, 'Bank BCA');
    expect(a.rows[1].toAccount, 'GoPay');
    expect(a.rows[2].type, TransactionType.income);
  });

  test('Identik dua kali di hari yang sama tetap dua baris dengan ref berbeda', () {
    const csv = 'date,amount,category\n2026-11-23,-18000,Kopi\n2026-11-23,-18000,Kopi\n';
    final a = ImportParser.analyze(ImportParser.parseCsv(csv));
    expect(a.rows.length, 2);
    expect(a.rows[0].externalRef != a.rows[1].externalRef, isTrue);
  });

  test('format tanggal', () {
    expect(ImportParser.parseFlexibleDate('23/11/2026'), DateTime(2026, 11, 23));
    expect(ImportParser.parseFlexibleDate('11/23/2026'), DateTime(2026, 11, 23));
    expect(ImportParser.parseFlexibleDate('23 Nov 2026'), DateTime(2026, 11, 23));
    expect(ImportParser.parseFlexibleDate('46349'), DateTime(2026, 11, 23));
  });
}
