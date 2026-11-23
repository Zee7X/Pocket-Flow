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
  final String? categoryType;
  final String? categoryIcon;
  final String? categoryColor;

  /// Dompet sumber (expense/transfer) atau tujuan (income).
  final String? walletId;

  /// Dompet tujuan untuk transfer antar dompet.
  final String? toWalletId;
  final String? merchant;

  /// manual | notification | ocr | shortcut | paste | ai | import | recurring | split | offline
  final String source;

  /// Hash dedupe untuk transaksi dari sumber otomatis / import.
  final String? externalRef;

  /// True bila transaksi dibuat saat offline dan belum terkirim ke server.
  final bool isPendingSync;

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
    this.categoryType,
    this.categoryIcon,
    this.categoryColor,
    this.walletId,
    this.toWalletId,
    this.merchant,
    this.source = 'manual',
    this.externalRef,
    this.isPendingSync = false,
  });

  bool get isTransfer => type == TransactionType.transfer;

  bool get isSavings =>
      categoryType == 'savings' ||
      categoryType == 'saving' ||
      (categoryName?.toLowerCase().contains('tabungan') == true) ||
      (categoryName?.toLowerCase().contains('investasi') == true) ||
      (categoryName?.toLowerCase().contains('darurat') == true);

  bool get isDebt =>
      categoryType == 'debt' ||
      (categoryName?.toLowerCase().contains('utang') == true) ||
      (categoryName?.toLowerCase().contains('cicilan') == true);

  /// True bila tanggal transaksi setelah hari ini (date-only comparison;
  /// dinormalisasi sehingga tidak terpengaruh jam/menit/detik).
  bool get isUpcoming {
    final now = DateTime.now();
    final txDate = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return txDate.isAfter(today);
  }

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
      paymentMethod: json['payment_method'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: cat?['name'] as String?,
      categoryType: cat?['type'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
      walletId: json['wallet_id'] as String?,
      toWalletId: json['to_wallet_id'] as String?,
      merchant: json['merchant'] as String?,
      source: json['source'] as String? ?? 'manual',
      externalRef: json['external_ref'] as String?,
      isPendingSync: json['_pending_sync'] as bool? ?? false,
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
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (walletId != null) 'wallet_id': walletId,
      if (toWalletId != null) 'to_wallet_id': toWalletId,
      if (merchant != null) 'merchant': merchant,
      'source': source,
      if (externalRef != null) 'external_ref': externalRef,
    };
  }
}
