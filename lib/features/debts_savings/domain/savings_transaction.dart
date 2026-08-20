// lib/features/debts_savings/domain/savings_transaction.dart
enum SavingsTransactionType {
  deposit,
  withdrawal;

  static SavingsTransactionType fromString(String value) {
    return value.toLowerCase() == 'withdrawal'
        ? SavingsTransactionType.withdrawal
        : SavingsTransactionType.deposit;
  }

  String toDbString() => name;
}

class SavingsTransaction {
  final String id;
  final String savingsGoalId;
  final String userId;
  final SavingsTransactionType type;
  final int amount;
  final DateTime transactionDate;
  final String? note;
  final DateTime createdAt;

  const SavingsTransaction({
    required this.id,
    required this.savingsGoalId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    this.note,
    required this.createdAt,
  });

  factory SavingsTransaction.fromJson(Map<String, dynamic> json) {
    final created = DateTime.parse(json['created_at'] as String);
    return SavingsTransaction(
      id: json['id'] as String,
      savingsGoalId: json['goal_id'] as String? ?? json['savings_goal_id'] as String? ?? '',
      userId: json['user_id'] as String,
      type: SavingsTransactionType.fromString(json['type'] as String? ?? 'deposit'),
      amount: (json['amount'] as num).toInt(),
      transactionDate: created,
      note: json['note'] as String?,
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_id': savingsGoalId,
      'user_id': userId,
      'type': type.toDbString(),
      'amount': amount,
      if (note != null) 'note': note,
    };
  }
}
