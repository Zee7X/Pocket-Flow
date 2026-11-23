// lib/features/insights/domain/insight_engine.dart
//
// Insight bulanan dihitung lokal dari riwayat transaksi (tanpa AI, tanpa
// biaya). Perbandingan dengan bulan lalu memakai periode yang setara
// (tanggal 1 s.d. hari yang sama) supaya adil di tengah bulan.
import '../../smart/domain/category_suggester.dart';
import '../../transactions/domain/transaction.dart';

enum InsightTone { good, bad, neutral }

enum InsightKind { trend, category, merchant, weekday, projection, savings }

class Insight {
  final InsightKind kind;
  final InsightTone tone;
  final String title;
  final String body;

  const Insight({
    required this.kind,
    required this.tone,
    required this.title,
    required this.body,
  });
}

class InsightEngine {
  const InsightEngine();

  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  bool _isSpending(TransactionModel t) =>
      t.type == TransactionType.expense && !t.isSavings;

  List<Insight> build({
    required List<TransactionModel> history,
    required int month,
    required int year,
    int? monthlyBudget,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final isCurrent = now.month == month && now.year == year;
    final lastDay = DateTime(year, month + 1, 0).day;
    final cutoffDay = isCurrent ? now.day : lastDay;

    bool inMonth(TransactionModel t, int m, int y, {int? upToDay}) =>
        t.transactionDate.month == DateTime(y, m).month &&
        t.transactionDate.year == DateTime(y, m).year &&
        (upToDay == null || t.transactionDate.day <= upToDay);

    final prev = DateTime(year, month - 1);
    final thisTx = history
        .where((t) => inMonth(t, month, year, upToDay: cutoffDay))
        .toList();
    final prevTxSame = history
        .where((t) => inMonth(t, prev.month, prev.year, upToDay: cutoffDay))
        .toList();

    final spendNow = thisTx
        .where(_isSpending)
        .fold<int>(0, (s, t) => s + t.amount);
    final spendPrev = prevTxSame
        .where(_isSpending)
        .fold<int>(0, (s, t) => s + t.amount);
    final out = <Insight>[];

    // 1. Tren total pengeluaran
    if (spendPrev > 0 && spendNow > 0) {
      final pct = ((spendNow - spendPrev) / spendPrev * 100).round();
      if (pct.abs() >= 5) {
        out.add(
          Insight(
            kind: InsightKind.trend,
            tone: pct > 0 ? InsightTone.bad : InsightTone.good,
            title: pct > 0
                ? 'Pengeluaran naik $pct%'
                : 'Pengeluaran turun ${pct.abs()}%',
            body:
                'Tanggal 1–$cutoffDay: ${_rp(spendNow)} dibanding ${_rp(spendPrev)} di periode yang sama bulan lalu.',
          ),
        );
      } else {
        out.add(
          Insight(
            kind: InsightKind.trend,
            tone: InsightTone.neutral,
            title: 'Pengeluaran stabil',
            body:
                'Tanggal 1–$cutoffDay: ${_rp(spendNow)}, hampir sama dengan bulan lalu (${_rp(spendPrev)}).',
          ),
        );
      }
    }

    // 2. Kategori dengan kenaikan terbesar
    Map<String, int> byCat(List<TransactionModel> l) {
      final m = <String, int>{};
      for (final t in l.where(_isSpending)) {
        final k = t.categoryName ?? 'Tanpa kategori';
        m[k] = (m[k] ?? 0) + t.amount;
      }
      return m;
    }

    final catNow = byCat(thisTx);
    final catPrev = byCat(prevTxSame);
    String? worstCat;
    var worstDelta = 0;
    catNow.forEach((k, v) {
      final p = catPrev[k] ?? 0;
      final d = v - p;
      if (p > 0 && d > worstDelta && d >= 50000 && d / p >= 0.2) {
        worstDelta = d;
        worstCat = k;
      }
    });
    if (worstCat != null) {
      final p = catPrev[worstCat]!;
      final pct = (worstDelta / p * 100).round();
      final topMerchant = _topMerchant(
        thisTx.where((t) => (t.categoryName ?? 'Tanpa kategori') == worstCat),
      );
      out.add(
        Insight(
          kind: InsightKind.category,
          tone: InsightTone.bad,
          title: '$worstCat naik $pct%',
          body:
              '${_rp(catNow[worstCat]!)} bulan ini vs ${_rp(p)} bulan lalu'
              '${topMerchant == null ? '' : ', paling banyak di ${topMerchant.$1}'}.',
        ),
      );
    }

    // 3. Merchant teratas
    final top = _topMerchant(thisTx.where(_isSpending));
    if (top != null && top.$3 >= 3) {
      out.add(
        Insight(
          kind: InsightKind.merchant,
          tone: InsightTone.neutral,
          title: 'Paling sering: ${top.$1}',
          body: '${top.$3} transaksi, total ${_rp(top.$2)} bulan ini.',
        ),
      );
    }

    // 4. Hari paling boros
    final byWeekday = List<int>.filled(7, 0);
    final countWeekday = List<int>.filled(7, 0);
    for (final t in thisTx.where(_isSpending)) {
      byWeekday[t.transactionDate.weekday - 1] += t.amount;
    }
    for (var d = 1; d <= cutoffDay; d++) {
      countWeekday[DateTime(year, month, d).weekday - 1]++;
    }
    var bestIdx = -1;
    var bestAvg = 0.0;
    var allAvg = 0.0;
    var nDays = 0;
    for (var i = 0; i < 7; i++) {
      if (countWeekday[i] == 0) continue;
      final avg = byWeekday[i] / countWeekday[i];
      allAvg += byWeekday[i];
      nDays += countWeekday[i];
      if (avg > bestAvg) {
        bestAvg = avg;
        bestIdx = i;
      }
    }
    if (nDays > 0) allAvg /= nDays;
    if (bestIdx >= 0 &&
        cutoffDay >= 14 &&
        thisTx.where(_isSpending).length >= 20 &&
        allAvg > 0 &&
        bestAvg > allAvg * 1.4) {
      out.add(
        Insight(
          kind: InsightKind.weekday,
          tone: InsightTone.neutral,
          title: 'Hari ${_days[bestIdx]} paling boros',
          body:
              'Rata-rata ${_rp(bestAvg.round())} per ${_days[bestIdx]}, dibanding ${_rp(allAvg.round())} per hari biasa.',
        ),
      );
    }

    // 5. Proyeksi akhir bulan
    if (isCurrent &&
        monthlyBudget != null &&
        monthlyBudget > 0 &&
        cutoffDay >= 5) {
      final projected = (spendNow / cutoffDay * lastDay).round();
      final over = projected - monthlyBudget;
      out.add(
        Insight(
          kind: InsightKind.projection,
          tone: over > 0 ? InsightTone.bad : InsightTone.good,
          title: over > 0
              ? 'Diproyeksikan lewat budget'
              : 'Masih di jalur budget',
          body: over > 0
              ? 'Dengan laju sekarang, total bulan ini sekitar ${_rp(projected)}, ${_rp(over)} di atas budget ${_rp(monthlyBudget)}.'
              : 'Dengan laju sekarang, total bulan ini sekitar ${_rp(projected)} dari budget ${_rp(monthlyBudget)}.',
        ),
      );
    }

    // 6. Rasio menabung
    final income = thisTx
        .where((t) => t.type == TransactionType.income)
        .fold<int>(0, (s, t) => s + t.amount);
    final saved = thisTx
        .where((t) => t.type == TransactionType.expense && t.isSavings)
        .fold<int>(0, (s, t) => s + t.amount);
    if (income > 0 && saved > 0) {
      final rate = (saved / income * 100).round();
      out.add(
        Insight(
          kind: InsightKind.savings,
          tone: rate >= 20 ? InsightTone.good : InsightTone.neutral,
          title: 'Menabung $rate% dari pemasukan',
          body: rate >= 20
              ? '${_rp(saved)} sudah masuk tabungan. Di atas patokan umum 20%.'
              : '${_rp(saved)} masuk tabungan. Patokan umum 20% berarti ${_rp((income * 0.2).round())}.',
        ),
      );
    }
    return out;
  }

  /// (nama, total, jumlah transaksi)
  (String, int, int)? _topMerchant(Iterable<TransactionModel> txs) {
    final sum = <String, int>{};
    final count = <String, int>{};
    final label = <String, String>{};
    for (final t in txs) {
      final name = t.merchant ?? t.description;
      if (name == null || name.trim().isEmpty) continue;
      final k = merchantKey(name);
      if (k.isEmpty) continue;
      sum[k] = (sum[k] ?? 0) + t.amount;
      count[k] = (count[k] ?? 0) + 1;
      label[k] ??= name;
    }
    if (sum.isEmpty) return null;
    final best = sum.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return (label[best]!, sum[best]!, count[best]!);
  }

  static String _rp(int v) {
    final s = v.abs().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '${v < 0 ? '-' : ''}Rp$s';
  }
}
