// lib/core/utils/amount_parser.dart
//
// Parsing nominal rupiah dari teks bebas: notifikasi, struk, ketikan.
// Mendukung "Rp25.000", "Rp 25.000,00", "IDR 25,000.00", "25rb", "1,5jt",
// "1.250.000", "2 juta", "50k".

/// Ubah string angka dengan pemisah ribuan/desimal (format ID atau EN)
/// menjadi rupiah utuh. Desimal (sen) dibuang.
int? parseNumberToken(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (s.isEmpty || !RegExp(r'\d').hasMatch(s)) return null;
  // Buang pemisah di ujung ("25.000," atau "25.000.")
  s = s.replaceAll(RegExp(r'[.,]+$'), '');

  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String intPart;
  if (lastDot >= 0 && lastComma >= 0) {
    // Dua jenis pemisah: yang terakhir adalah desimal.
    final decIdx = lastDot > lastComma ? lastDot : lastComma;
    intPart = s.substring(0, decIdx);
  } else if (lastDot >= 0 || lastComma >= 0) {
    final sep = lastDot >= 0 ? '.' : ',';
    final parts = s.split(sep);
    final tail = parts.last;
    final allThousands = parts.skip(1).every((p) => p.length == 3);
    if (allThousands) {
      intPart = s;
    } else if (parts.length == 2 && tail.length <= 2) {
      intPart = parts.first; // desimal: "25000,00" atau "1,5" (tanpa satuan)
    } else {
      intPart = s;
    }
  } else {
    intPart = s;
  }
  final digits = intPart.replaceAll(RegExp(r'[.,]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// Parse angka yang mungkin memakai satuan (rb/ribu/k/jt/juta).
/// Contoh: "25rb" -> 25000, "1,5jt" -> 1500000, "50k" -> 50000.
int? parseAmountWithUnit(String number, String? unit) {
  final u = (unit ?? '').toLowerCase().trim();
  int mult = 1;
  if (u == 'rb' || u == 'ribu' || u == 'k' || u == 'rbu') mult = 1000;
  if (u == 'jt' || u == 'juta') mult = 1000000;
  if (mult == 1) return parseNumberToken(number);
  final normalized = number.replaceAll('.', ',');
  final parts = normalized.split(',');
  final whole = int.tryParse(parts.first.replaceAll(RegExp(r'\D'), '')) ?? 0;
  double frac = 0;
  if (parts.length > 1) {
    final f = parts[1].replaceAll(RegExp(r'\D'), '');
    if (f.isNotEmpty) frac = int.parse(f) / _pow10(f.length);
  }
  return ((whole + frac) * mult).round();
}

int _pow10(int n) {
  var r = 1;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

class AmountMatch {
  final int value;
  final int start;
  final int end;

  /// True bila ada penanda mata uang (Rp/IDR) atau satuan (rb/jt).
  final bool explicit;
  const AmountMatch(this.value, this.start, this.end, {this.explicit = true});
}

final _currencyRe = RegExp(
  r'(?:rp\.?|idr)\s*([0-9][0-9.,]*)\s*(rb|ribu|k|jt|juta)?\b',
  caseSensitive: false,
);
final _unitRe = RegExp(
  r'(?<![\w.,])([0-9]+(?:[.,][0-9]+)?)\s*(rb|ribu|rbu|k|jt|juta)\b',
  caseSensitive: false,
);

/// Semua nominal yang ditandai Rp/IDR atau satuan rb/jt, urut posisi.
List<AmountMatch> findAmounts(String text) {
  final out = <AmountMatch>[];
  for (final m in _currencyRe.allMatches(text)) {
    final v = parseAmountWithUnit(m.group(1)!, m.group(2));
    if (v != null && v > 0) out.add(AmountMatch(v, m.start, m.end));
  }
  for (final m in _unitRe.allMatches(text)) {
    if (out.any((o) => m.start >= o.start && m.start < o.end)) continue;
    final v = parseAmountWithUnit(m.group(1)!, m.group(2));
    if (v != null && v > 0) out.add(AmountMatch(v, m.start, m.end));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Angka polos tanpa penanda, mis. "bakso 25000". Hanya dipakai sebagai
/// cadangan untuk input ketikan.
List<AmountMatch> findBareNumbers(String text) {
  final out = <AmountMatch>[];
  for (final m in RegExp(
    r'(?<![\w.,])(\d{1,3}(?:[.,]\d{3})+|\d{3,})(?![\w.,]*\d)',
  ).allMatches(text)) {
    final v = parseNumberToken(m.group(1)!);
    if (v != null && v >= 100) {
      out.add(AmountMatch(v, m.start, m.end, explicit: false));
    }
  }
  return out;
}
