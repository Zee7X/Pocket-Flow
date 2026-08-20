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
    return SavingsTransaction(
      id: json['id'] as String,
      savingsGoalId: json['savings_goal_id'] as String,
      userId: json['user_id'] as String,
      type: SavingsTransactionType.fromString(json['type'] as String? ?? 'deposit'),
      amount: (json['amount'] as num).toInt(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'savings_goal_id': savingsGoalId,
      'user_id': userId,
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      if (note != null) 'note': note,
    };
  }
}
