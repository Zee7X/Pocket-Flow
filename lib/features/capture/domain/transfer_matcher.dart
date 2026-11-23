// lib/features/capture/domain/transfer_matcher.dart
//
// Top up e-wallet dari rekening sendiri menghasilkan dua notifikasi:
//   BCA   : "Top Up GoPay Rp100.000 berhasil"   (keluar)
//   GoPay : "Top up Rp100.000 berhasil"         (masuk)
// Keduanya bukan pengeluaran/pemasukan, melainkan transfer antar dompet.
// Matcher ini menggabungkan pasangan seperti itu menjadi satu transfer.
import '../../transactions/domain/transaction.dart';
import 'capture_models.dart';

class TransferPair {
  final ParsedCapture outgoing;
  final ParsedCapture incoming;
  const TransferPair(this.outgoing, this.incoming);
}

class TransferMatcher {
  final Duration window;

  /// Selisih maksimal karena biaya admin top up.
  final int maxFee;

  const TransferMatcher({
    this.window = const Duration(minutes: 15),
    this.maxFee = 2500,
  });

  /// Mengembalikan daftar baru di mana pasangan transfer sudah digabung.
  /// Item transfer memakai providerKey = sumber dan
  /// counterpartyProviderKey = tujuan.
  List<ParsedCapture> merge(List<ParsedCapture> items) {
    final used = <int>{};
    final out = <ParsedCapture>[];
    for (var i = 0; i < items.length; i++) {
      if (used.contains(i)) continue;
      final a = items[i];
      if (a.type != TransactionType.expense) continue;
      for (var j = 0; j < items.length; j++) {
        if (i == j || used.contains(j)) continue;
        final b = items[j];
        if (isPair(a, b)) {
          used
            ..add(i)
            ..add(j);
          out.add(
            ParsedCapture(
              type: TransactionType.transfer,
              amount: b.amount,
              merchant: a.merchant ?? 'Transfer',
              providerKey: a.providerKey,
              counterpartyProviderKey: b.providerKey,
              occurredAt: a.occurredAt,
              confidence: ((a.confidence + b.confidence) / 2 + 0.1)
                  .clamp(0, 1)
                  .toDouble(),
              dedupeHash: a.dedupeHash,
              source: a.source,
              sourceApp: '${a.sourceApp ?? '-'} → ${b.sourceApp ?? '-'}',
              isTopUp: true,
            ),
          );
          break;
        }
      }
    }
    for (var i = 0; i < items.length; i++) {
      if (!used.contains(i)) out.add(items[i]);
    }
    out.sort((x, y) => y.occurredAt.compareTo(x.occurredAt));
    return out;
  }

  bool isPair(ParsedCapture out, ParsedCapture inc) {
    if (out.type != TransactionType.expense ||
        inc.type != TransactionType.income) {
      return false;
    }
    if (out.providerKey == null || inc.providerKey == null) return false;
    if (out.providerKey == inc.providerKey) return false;
    final diff = out.amount - inc.amount;
    if (diff < 0 || diff > maxFee) return false;
    if (out.occurredAt.difference(inc.occurredAt).abs() > window) return false;
    // Harus ada petunjuk: salah satu top up, atau sisi keluar menyebut tujuan.
    return out.isTopUp ||
        inc.isTopUp ||
        out.counterpartyProviderKey == inc.providerKey;
  }
}
