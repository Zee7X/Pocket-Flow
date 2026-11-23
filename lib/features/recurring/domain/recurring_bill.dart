// lib/features/recurring/domain/recurring_bill.dart
enum BillCadence {
  weekly,
  monthly,
  yearly;

  static BillCadence fromString(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => BillCadence.monthly);

  String get label => switch (this) {
    BillCadence.weekly => 'Mingguan',
    BillCadence.monthly => 'Bulanan',
    BillCadence.yearly => 'Tahunan',
  };

  DateTime next(DateTime from) => switch (this) {
    BillCadence.weekly => from.add(const Duration(days: 7)),
    BillCadence.monthly => _addMonths(from, 1),
    BillCadence.yearly => _addMonths(from, 12),
  };

  static DateTime _addMonths(DateTime d, int n) {
    final target = DateTime(d.year, d.month + n, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(
      target.year,
      target.month,
      d.day > lastDay ? lastDay : d.day,
    );
  }
}

class RecurringBill {
  final String id;
  final String userId;
  final String name;
  final int amount;
  final String? categoryId;
  final String? walletId;
  final String? debtId;
  final BillCadence cadence;
  final DateTime nextDueDate;
  final int remindDaysBefore;
  final bool isActive;
  final String? merchantKey;

  const RecurringBill({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    this.categoryId,
    this.walletId,
    this.debtId,
    this.cadence = BillCadence.monthly,
    required this.nextDueDate,
    this.remindDaysBefore = 2,
    this.isActive = true,
    this.merchantKey,
  });

  int daysUntilDue(DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final d = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return d.difference(t).inDays;
  }

  /// Biaya per bulan (untuk total langganan).
  int get monthlyCost => switch (cadence) {
    BillCadence.weekly => (amount * 52 / 12).round(),
    BillCadence.monthly => amount,
    BillCadence.yearly => (amount / 12).round(),
  };

  factory RecurringBill.fromJson(Map<String, dynamic> j) => RecurringBill(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    name: j['name'] as String,
    amount: (j['amount'] as num).toInt(),
    categoryId: j['category_id'] as String?,
    walletId: j['wallet_id'] as String?,
    debtId: j['debt_id'] as String?,
    cadence: BillCadence.fromString(j['cadence'] as String?),
    nextDueDate: DateTime.parse(j['next_due_date'] as String),
    remindDaysBefore: (j['remind_days_before'] as num?)?.toInt() ?? 2,
    isActive: j['is_active'] as bool? ?? true,
    merchantKey: j['merchant_key'] as String?,
  );
}

/// Saran langganan yang terdeteksi dari riwayat transaksi.
class RecurringSuggestion {
  final String name;
  final String merchantKey;
  final int amount;
  final String? categoryId;
  final String? walletId;
  final DateTime lastDate;
  final DateTime nextDueDate;
  final int occurrences;

  const RecurringSuggestion({
    required this.name,
    required this.merchantKey,
    required this.amount,
    this.categoryId,
    this.walletId,
    required this.lastDate,
    required this.nextDueDate,
    required this.occurrences,
  });
}
