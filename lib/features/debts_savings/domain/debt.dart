// lib/features/debts_savings/domain/debt.dart
enum DebtType {
  creditCard,
  paylater,
  personalLoan,
  mortgage,
  other;

  static DebtType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'credit_card':
        return DebtType.creditCard;
      case 'paylater':
        return DebtType.paylater;
      case 'personal_loan':
        return DebtType.personalLoan;
      case 'mortgage':
        return DebtType.mortgage;
      default:
        return DebtType.other;
    }
  }

  String toDbString() {
    switch (this) {
      case DebtType.creditCard:
        return 'credit_card';
      case DebtType.paylater:
        return 'paylater';
      case DebtType.personalLoan:
        return 'personal_loan';
      case DebtType.mortgage:
        return 'mortgage';
      case DebtType.other:
        return 'other';
    }
  }

  String get displayName {
    switch (this) {
      case DebtType.creditCard:
        return 'Kartu Kredit';
      case DebtType.paylater:
        return 'Paylater';
      case DebtType.personalLoan:
        return 'Pinjaman Pribadi';
      case DebtType.mortgage:
        return 'KPR / Cicilan';
      case DebtType.other:
        return 'Lainnya';
    }
  }
}

class Debt {
  final String id;
  final String userId;
  final String name;
  final DebtType debtType;
  final int totalAmount;
  final int remainingAmount;
  final int minimumPayment;
  final int? interestRate;
  final int? dueDay;
  final bool isPaid;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.debtType,
    required this.totalAmount,
    required this.remainingAmount,
    this.minimumPayment = 0,
    this.interestRate,
    this.dueDay,
    this.isPaid = false,
    required this.createdAt,
  });

  int get paidAmount => totalAmount - remainingAmount;
  double get paidPercentage =>
      totalAmount > 0 ? (paidAmount / totalAmount).clamp(0.0, 1.0) : 0.0;

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      debtType: DebtType.fromString(json['debt_type'] as String? ?? 'other'),
      totalAmount: (json['total_amount'] as num).toInt(),
      remainingAmount: (json['remaining_amount'] as num).toInt(),
      minimumPayment: (json['minimum_payment'] as num?)?.toInt() ?? 0,
      interestRate: (json['interest_rate'] as num?)?.toInt(),
      dueDay: (json['due_day'] as num?)?.toInt(),
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'debt_type': debtType.toDbString(),
      'total_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'minimum_payment': minimumPayment,
      if (interestRate != null) 'interest_rate': interestRate,
      if (dueDay != null) 'due_day': dueDay,
      'is_paid': isPaid,
    };
  }
}
