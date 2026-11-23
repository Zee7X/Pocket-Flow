// lib/core/utils/date_id.dart
// Format tanggal bahasa Indonesia tanpa perlu inisialisasi locale intl.
const kMonthsId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];
const kMonthsShortId = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];
const kDaysId = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

/// "23 Nov 2026"
String dateShortId(DateTime d) =>
    '${d.day} ${kMonthsShortId[d.month - 1]} ${d.year}';

/// "Senin, 23 November 2026"
String dateLongId(DateTime d) =>
    '${kDaysId[d.weekday - 1]}, ${d.day} ${kMonthsId[d.month - 1]} ${d.year}';

/// "Hari ini", "Kemarin", atau "23 Nov"
String dateRelativeId(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final x = DateTime(d.year, d.month, d.day);
  final diff = today.difference(x).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  if (diff == -1) return 'Besok';
  if (x.year == today.year) return '${d.day} ${kMonthsShortId[d.month - 1]}';
  return dateShortId(d);
}

/// "08.15"
String timeId(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
