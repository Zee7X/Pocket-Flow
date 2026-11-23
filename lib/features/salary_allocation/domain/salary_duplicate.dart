// lib/features/salary_allocation/domain/salary_duplicate.dart
//
// Mencegah gaji tercatat dua kali.
//
// Saat gaji dialokasikan, aplikasi membuat transaksi pemasukan
// "Gaji Periode M/YYYY". Bila kemudian gaji yang sama masuk lagi lewat
// notifikasi bank, AI, struk, atau diketik manual, itu duplikat.
//
// Dianggap gaji yang sama bila ada entri gaji yang:
// * tanggal terimanya dekat (±7 hari) dengan tanggal pemasukan baru, ATAU
//   periodenya sama dengan bulan pemasukan baru; DAN
// * nominalnya mirip (selisih ≤10%), ATAU teksnya menyebut gaji/payroll
//   dan selisih nominal ≤30% (potongan pajak/BPJS, bonus kecil).
//
// Bukan duplikat:
// * gaji periode lain (mis. perkiraan gaji bulan depan),
// * pemasukan lain di bulan yang sama (freelance, bonus, THR, refund)
//   yang nominalnya jauh berbeda dan tidak menyebut gaji.
import 'salary_entry.dart';

final _salaryWords = RegExp(r'\b(gaji|gajian|payroll|salary|upah)\b', caseSensitive: false);
final _notSalaryWords = RegExp(r'\b(freelance|bonus|thr|refund|cashback|komisi|jual|proyek)\b', caseSensitive: false);

SalaryEntry? matchSalaryEntry(
  List<SalaryEntry> entries, {
  required int amount,
  required DateTime date,
  String? text,
}) {
  final t = text ?? '';
  if (_notSalaryWords.hasMatch(t) && !_salaryWords.hasMatch(t)) return null;
  final mentionsSalary = _salaryWords.hasMatch(t);
  final day = DateTime(date.year, date.month, date.day);

  SalaryEntry? best;
  var bestDays = 1 << 30;
  for (final e in entries) {
    final sd = DateTime(e.salaryDate.year, e.salaryDate.month, e.salaryDate.day);
    final days = sd.difference(day).inDays.abs();
    final samePeriod = e.periodMonth == date.month && e.periodYear == date.year;
    if (days > 7 && !samePeriod) continue;

    final diff = (amount - e.amount).abs() / (e.amount == 0 ? 1 : e.amount);
    final amountOk = diff <= 0.10 || (mentionsSalary && diff <= 0.30);
    if (!amountOk) continue;

    if (days < bestDays) {
      best = e;
      bestDays = days;
    }
  }
  return best;
}

/// Catatan transaksi pemasukan yang dibuat fungsi alokasi gaji di database.
String salaryTransactionNote(SalaryEntry e) => 'Gaji Periode ${e.periodMonth}/${e.periodYear}';
