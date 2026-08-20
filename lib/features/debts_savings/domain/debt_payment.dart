// lib/features/debts_savings/domain/debt_payment.dart
class DebtPayment {
  final String id;
  final String debtId;
  final String userId;
  final int amount;
  final DateTime paymentDate;
  final String? note;
  final DateTime createdAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.userId,
    required this.amount,
    required this.paymentDate,
    this.note,
    required this.createdAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] as String,
      debtId: json['debt_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toInt(),
      paymentDate: DateTime.parse(json['payment_date'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'debt_id': debtId,
      'user_id': userId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T').first,
      if (note != null) 'note': note,
    };
  }
}
