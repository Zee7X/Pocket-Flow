// lib/features/salary_allocation/domain/salary_entry.dart
class SalaryEntry {
  final String id;
  final String userId;
  final int amount;
  final DateTime salaryDate;
  final int periodMonth;
  final int periodYear;
  final String? note;
  final DateTime createdAt;

  const SalaryEntry({
    required this.id,
    required this.userId,
    required this.amount,
    required this.salaryDate,
    required this.periodMonth,
    required this.periodYear,
    this.note,
    required this.createdAt,
  });

  factory SalaryEntry.fromJson(Map<String, dynamic> json) {
    return SalaryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toInt(),
      salaryDate: DateTime.parse(json['salary_date'] as String),
      periodMonth: (json['period_month'] as num).toInt(),
      periodYear: (json['period_year'] as num).toInt(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
