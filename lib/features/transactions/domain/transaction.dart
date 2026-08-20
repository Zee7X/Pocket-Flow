// lib/features/transactions/domain/transaction.dart
enum TransactionType {
  expense,
  income,
  transfer;

  static TransactionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'income':
        return TransactionType.income;
      case 'transfer':
        return TransactionType.transfer;
      case 'expense':
      default:
        return TransactionType.expense;
    }
  }

  String toDbString() => name;
}

class TransactionModel {
  final String id;
  final String userId;
  final String? categoryId;
  final TransactionType type;
  final int amount;
  final DateTime transactionDate;
  final String? description;
  final String? paymentMethod;
  final DateTime createdAt;
  final String? categoryName;
  final String? categoryIcon;
  final String? categoryColor;

  const TransactionModel({
    required this.id,
    required this.userId,
    this.categoryId,
    required this.type,
    required this.amount,
    required this.transactionDate,
    this.description,
    this.paymentMethod,
    required this.createdAt,
    this.categoryName,
    this.categoryIcon,
    this.categoryColor,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final cat = json['pf_categories'] as Map<String, dynamic>?;
    final note = json['note'] as String? ?? json['description'] as String?;
    return TransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String?,
      type: TransactionType.fromString(json['type'] as String? ?? 'expense'),
      amount: (json['amount'] as num).toInt(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      description: note,
      paymentMethod: null,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: cat?['name'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'note': description,
    };
  }
}
