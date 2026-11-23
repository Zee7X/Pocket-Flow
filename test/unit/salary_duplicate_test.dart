import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/features/salary_allocation/domain/salary_duplicate.dart';
import 'package:pocket_flow/features/salary_allocation/domain/salary_entry.dart';

SalaryEntry entry(int amount, DateTime date, int month, int year) => SalaryEntry(
      id: '$month-$year',
      userId: 'u',
      amount: amount,
      salaryDate: date,
      periodMonth: month,
      periodYear: year,
      createdAt: date,
    );

void main() {
  final nov = entry(8500000, DateTime(2026, 11, 1), 11, 2026);
  // Perkiraan gaji Desember, diterima 25 November.
  final dec = entry(8500000, DateTime(2026, 11, 25), 12, 2026);

  test('notifikasi gaji masuk di tanggal yang sama = duplikat', () {
    final m = matchSalaryEntry([nov], amount: 8500000, date: DateTime(2026, 11, 1), text: 'Transfer masuk dari PT Maju');
    expect(m?.id, '11-2026');
  });

  test('gaji bersih sedikit beda karena potongan tetap dianggap gaji yang sama', () {
    final m = matchSalaryEntry([nov], amount: 8150000, date: DateTime(2026, 11, 2), text: 'Payroll November');
    expect(m?.id, '11-2026');
  });

  test('gaji periode Desember yang diterima 25 November dicocokkan ke Desember', () {
    final m = matchSalaryEntry([nov, dec], amount: 8500000, date: DateTime(2026, 11, 25), text: 'Gaji masuk');
    expect(m?.id, '12-2026');
  });

  test('freelance di bulan yang sama bukan duplikat', () {
    expect(matchSalaryEntry([nov], amount: 1200000, date: DateTime(2026, 11, 12), text: 'gaji freelance'), isNull);
    expect(matchSalaryEntry([nov], amount: 8500000, date: DateTime(2026, 11, 12), text: 'Bonus proyek'), isNull);
  });

  test('pemasukan jauh dari tanggal gajian dan beda periode bukan duplikat', () {
    expect(matchSalaryEntry([dec], amount: 8500000, date: DateTime(2026, 10, 3), text: 'Transfer masuk'), isNull);
  });
}
