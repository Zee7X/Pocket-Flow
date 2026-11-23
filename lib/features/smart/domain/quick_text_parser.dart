// lib/features/smart/domain/quick_text_parser.dart
//
// Parser lokal untuk input ketikan / suara, dipakai bila AI tidak tersedia
// (offline, kuota habis, atau Edge Function belum dipasang).
//
//   "makan bakso 25rb pakai gopay kemarin"
//   "gaji 8,5jt masuk bca, bayar kos 1,8jt"
import '../../../core/utils/amount_parser.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/domain/payment_providers.dart';

class DraftTransaction {
  final TransactionType type;
  final int amount;
  final String? merchant;
  final String? note;
  final DateTime date;
  final String? providerKey;
  final String? toProviderKey;

  /// Diisi oleh AI (id kategori/dompet pengguna) atau oleh suggester lokal.
  final String? categoryId;
  final String? walletId;
  final String? toWalletId;

  const DraftTransaction({
    required this.type,
    required this.amount,
    this.merchant,
    this.note,
    required this.date,
    this.providerKey,
    this.toProviderKey,
    this.categoryId,
    this.walletId,
    this.toWalletId,
  });

  DraftTransaction copyWith({
    TransactionType? type,
    int? amount,
    String? merchant,
    String? note,
    DateTime? date,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    bool clearCategory = false,
  }) => DraftTransaction(
    type: type ?? this.type,
    amount: amount ?? this.amount,
    merchant: merchant ?? this.merchant,
    note: note ?? this.note,
    date: date ?? this.date,
    providerKey: providerKey,
    toProviderKey: toProviderKey,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    walletId: walletId ?? this.walletId,
    toWalletId: toWalletId ?? this.toWalletId,
  );
}

class QuickTextParser {
  final DateTime now;
  QuickTextParser({DateTime? now}) : now = now ?? DateTime.now();

  static final _incomeWords = RegExp(
    r'\b(gaji|gajian|terima|diterima|dapat|dapet|masuk|bonus|thr|freelance|dibayar|honor|komisi|refund|cashback|jual|hasil jualan|transferan)\b',
    caseSensitive: false,
  );
  static final _transferWords = RegExp(
    r'\b(top ?up|isi saldo|pindah(in)? (dana|saldo|uang)|tarik tunai|tarik ke)\b',
    caseSensitive: false,
  );

  List<DraftTransaction> parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return const [];
    final segments = text
        .split(
          RegExp(
            r'\n|;|,(?!\d)|\s+(?:dan|terus|lalu|trus)\s+',
            caseSensitive: false,
          ),
        )
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final out = <DraftTransaction>[];
    // Kata waktu di awal kalimat ("kemarin makan 20rb, parkir 5rb") berlaku
    // untuk semua; kata waktu di tengah hanya untuk bagian itu.
    final sharedDate = segments.isEmpty ? null : _date(segments.first);
    for (final seg in segments) {
      var amounts = findAmounts(seg);
      if (amounts.isEmpty) amounts = findBareNumbers(seg);
      if (amounts.isEmpty) continue;
      final a = amounts.first;

      final providers = _providers(seg);
      TransactionType type;
      if (_transferWords.hasMatch(seg) && providers.length >= 2) {
        type = TransactionType.transfer;
      } else if (_incomeWords.hasMatch(seg)) {
        type = TransactionType.income;
      } else {
        type = TransactionType.expense;
      }

      final merchant = _describe(seg, a);
      String? from = providers.isNotEmpty ? providers.first : null;
      String? to;
      if (type == TransactionType.transfer) {
        (from, to) = _transferDirection(seg, providers);
      }
      out.add(
        DraftTransaction(
          type: type,
          amount: a.value,
          merchant: type == TransactionType.transfer
              ? 'Transfer antar dompet'
              : merchant,
          note: merchant,
          date:
              _date(seg) ??
              sharedDate ??
              DateTime(now.year, now.month, now.day),
          providerKey: from,
          toProviderKey: to,
        ),
      );
    }
    return out;
  }

  /// "top up gopay dari bca" -> (bca, gopay); "pindah saldo bca ke dana" -> (bca, dana)
  (String?, String?) _transferDirection(String seg, List<String> providers) {
    final l = seg.toLowerCase();
    String? keyAfter(String word) {
      for (final p in PaymentProviders.all) {
        if (!providers.contains(p.key)) continue;
        for (final a in p.aliases) {
          if (RegExp('\\b$word\\s+${RegExp.escape(a)}\\b').hasMatch(l)) {
            return p.key;
          }
        }
      }
      return null;
    }

    final from = keyAfter('dari');
    final to = keyAfter('ke') ?? keyAfter('top ?up') ?? keyAfter('isi saldo');
    final a = providers[0];
    final b = providers[1];
    if (from != null) return (from, from == a ? b : a);
    if (to != null) return (to == a ? b : a, to);
    return (a, b);
  }

  List<String> _providers(String seg) {
    final out = <String>[];
    final lower = seg.toLowerCase();
    final hits = <(int, String)>[];
    for (final p in PaymentProviders.all) {
      for (final a in p.aliases) {
        final m = RegExp(
          '(^|[^a-z])${RegExp.escape(a)}([^a-z]|\$)',
        ).firstMatch(lower);
        if (m != null) {
          hits.add((m.start, p.key));
          break;
        }
      }
    }
    hits.sort((x, y) => x.$1.compareTo(y.$1));
    for (final h in hits) {
      if (!out.contains(h.$2)) out.add(h.$2);
    }
    // "gopaylater" juga cocok dengan "gopay": buang yang lebih umum.
    if (out.contains('gopaylater')) out.remove('gopay');
    return out;
  }

  DateTime? _date(String s) {
    final l = s.toLowerCase();
    final today = DateTime(now.year, now.month, now.day);
    if (l.contains('kemarin lusa')) {
      return today.subtract(const Duration(days: 2));
    }
    if (RegExp(r'\b(kemarin|kemaren|kmrn)\b').hasMatch(l)) {
      return today.subtract(const Duration(days: 1));
    }
    final ago = RegExp(r'(\d+)\s*hari (yang )?lalu').firstMatch(l);
    if (ago != null) {
      return today.subtract(Duration(days: int.parse(ago.group(1)!)));
    }
    final tgl = RegExp(r'\b(?:tgl|tanggal)\s*(\d{1,2})\b').firstMatch(l);
    if (tgl != null) {
      final d = int.parse(tgl.group(1)!);
      var candidate = DateTime(now.year, now.month, d);
      if (candidate.isAfter(today)) {
        candidate = DateTime(now.year, now.month - 1, d);
      }
      return candidate;
    }
    final dm = RegExp(
      r'\b(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?\b',
    ).firstMatch(l);
    if (dm != null) {
      final d = int.parse(dm.group(1)!);
      final m = int.parse(dm.group(2)!);
      var y = dm.group(3) == null ? now.year : int.parse(dm.group(3)!);
      if (y < 100) y += 2000;
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) return DateTime(y, m, d);
    }
    return null;
  }

  static final _filler = RegExp(
    r'\b(pakai|pake|via|dari|ke|pakek|bayar pakai|dengan|dgn|kemarin|kemaren|kmrn|hari ini|tadi|barusan|lusa|tgl|tanggal|\d+ hari (yang )?lalu|habis|abis|sebesar|senilai|buat|untuk|beli|bayar|masuk|terima|dapat|dapet|rp|idr)\b',
    caseSensitive: false,
  );

  String? _describe(String seg, AmountMatch amount) {
    var s = seg.replaceRange(amount.start, amount.end, ' ');
    // Buang nama dompet.
    for (final p in PaymentProviders.all) {
      for (final a in p.aliases) {
        s = s.replaceAll(
          RegExp(
            '(^|[^a-z])${RegExp.escape(a)}(?=[^a-z]|\$)',
            caseSensitive: false,
          ),
          ' ',
        );
      }
    }
    s = s.replaceAll(RegExp(r'\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b'), ' ');
    s = s.replaceAll(_filler, ' ');
    s = s
        .replaceAll(RegExp(r'[^\w&\x27 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.isEmpty) return null;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Parser struk lokal (cadangan bila AI tidak tersedia).
class ReceiptTextParser {
  static final _totalLine = RegExp(
    r'^(grand\s*total|total\s*(bayar|belanja|pembayaran|harga|tagihan)?|jumlah\s*(bayar|total)?|tagihan|amount due|total due)\b',
    caseSensitive: false,
  );
  static final _notTotal = RegExp(
    r'(sub\s*total|total\s*(item|qty|disc|diskon|hemat|kembali)|kembalian|change|tunai|cash|pajak|ppn|tax|service)',
    caseSensitive: false,
  );

  DraftTransaction? parse(String ocrText, {DateTime? now}) {
    final lines = ocrText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    int? total;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!_totalLine.hasMatch(l) || _notTotal.hasMatch(l)) continue;
      final nums = _numbersIn(l);
      if (nums.isEmpty && i + 1 < lines.length) {
        nums.addAll(_numbersIn(lines[i + 1]));
      }
      if (nums.isNotEmpty) {
        final v = nums.reduce((a, b) => a > b ? a : b);
        if (total == null || v > total) total = v;
      }
    }
    // Cadangan: angka terbesar di struk yang masuk akal.
    total ??= [for (final l in lines) ..._numbersIn(l)]
        .where((v) => v >= 500 && v < 100000000)
        .fold<int?>(null, (m, v) => m == null || v > m ? v : m);
    if (total == null) return null;

    final merchant = lines.firstWhere(
      (l) =>
          RegExp(r'[A-Za-z]{3,}').hasMatch(l) &&
          !RegExp(
            r'(struk|receipt|nota|invoice|tanggal|date)',
            caseSensitive: false,
          ).hasMatch(l),
      orElse: () => lines.first,
    );
    final n = now ?? DateTime.now();
    final date =
        QuickTextParser(now: n)._date(ocrText) ??
        DateTime(n.year, n.month, n.day);
    return DraftTransaction(
      type: TransactionType.expense,
      amount: total,
      merchant: _titleCase(merchant),
      note: _titleCase(merchant),
      date: date.isAfter(n) ? DateTime(n.year, n.month, n.day) : date,
    );
  }

  List<int> _numbersIn(String l) {
    final out = <int>[];
    for (final m in RegExp(
      r'(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?|\d{4,})',
    ).allMatches(l)) {
      final v = parseNumberToken(m.group(1)!);
      if (v != null) out.add(v);
    }
    return out;
  }

  String _titleCase(String s) {
    final cleaned = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned
        .split(' ')
        .map(
          (w) =>
              w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
