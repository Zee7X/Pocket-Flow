// lib/features/recurring/domain/recurring_detector.dart
//
// Mendeteksi langganan / tagihan rutin dari riwayat transaksi:
// merchant (atau catatan) yang sama, nominal mirip (±10%), muncul di
// minimal 2 bulan berbeda dengan jarak ~1 bulan.
import '../../smart/domain/category_suggester.dart';
import '../../transactions/domain/transaction.dart';
import 'recurring_bill.dart';

class RecurringDetector {
  const RecurringDetector();

  List<RecurringSuggestion> detect(
    List<TransactionModel> history, {
    Set<String> ignoreKeys = const {},
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final groups = <String, List<TransactionModel>>{};
    for (final t in history) {
      if (t.type != TransactionType.expense) continue;
      if (t.transactionDate.isAfter(now)) continue;
      final label = t.merchant ?? t.description;
      if (label == null || label.trim().isEmpty) continue;
      final key = merchantKey(label);
      if (key.isEmpty || ignoreKeys.contains(key)) continue;
      groups.putIfAbsent(key, () => []).add(t);
    }

    final out = <RecurringSuggestion>[];
    groups.forEach((key, txs) {
      if (txs.length < 2) return;
      txs.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
      final last = txs.last;
      // Ambil transaksi yang nominalnya mirip dengan transaksi terakhir.
      final similar = txs
          .where((t) => (t.amount - last.amount).abs() <= last.amount * 0.1)
          .toList();
      final months = {
        for (final t in similar)
          t.transactionDate.year * 12 + t.transactionDate.month,
      };
      if (months.length < 2) return;
      // Jarak antar kemunculan rata-rata 25–35 hari.
      final gaps = <int>[];
      for (var i = 1; i < similar.length; i++) {
        gaps.add(
          similar[i].transactionDate
              .difference(similar[i - 1].transactionDate)
              .inDays,
        );
      }
      final monthlyGaps = gaps.where((g) => g >= 25 && g <= 35).length;
      if (monthlyGaps < 1 || monthlyGaps < gaps.length * 0.5) return;
      // Terlalu sering (mis. makan / belanja di tempat yang sama) bukan
      // langganan: hitung dari SEMUA transaksi merchant ini.
      final allMonths = {
        for (final t in txs)
          t.transactionDate.year * 12 + t.transactionDate.month,
      };
      if (txs.length / allMonths.length > 1.3) return;
      // Tanggal dalam bulan harus konsisten (selisih maks 5 hari).
      final days = similar.map((t) => t.transactionDate.day).toList()..sort();
      if (days.last - days.first > 5) return;

      var next = BillCadence.monthly.next(last.transactionDate);
      while (next.isBefore(DateTime(now.year, now.month, now.day))) {
        next = BillCadence.monthly.next(next);
      }
      out.add(
        RecurringSuggestion(
          name: last.merchant ?? last.description ?? key,
          merchantKey: key,
          amount: last.amount,
          categoryId: last.categoryId,
          walletId: last.walletId,
          lastDate: last.transactionDate,
          nextDueDate: next,
          occurrences: similar.length,
        ),
      );
    });
    out.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return out;
  }
}
