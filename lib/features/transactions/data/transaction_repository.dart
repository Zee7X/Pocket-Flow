// lib/features/transactions/data/transaction_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch transactions for a given month and year
  Future<List<TransactionModel>> getTransactions({
    required int month,
    required int year,
  }) async {
    final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endStr = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    final res = await _client
        .from('pf_transactions')
        .select('*, pf_categories(name, icon, color)')
        .eq('user_id', _userId)
        .gte('transaction_date', startStr)
        .lt('transaction_date', endStr)
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    return (res as List).map((json) => TransactionModel.fromJson(json)).toList();
  }

  /// Create a transaction and optionally update monthly budget spent_amount
  Future<TransactionModel> createTransaction({
    String? categoryId,
    required TransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? description,
    String? paymentMethod,
  }) async {
    final map = <String, dynamic>{
      'user_id': _userId,
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
    };
    if (categoryId != null) map['category_id'] = categoryId;
    if (description != null) map['description'] = description.trim();
    if (paymentMethod != null) map['payment_method'] = paymentMethod;

    final res = await _client
        .from('pf_transactions')
        .insert(map)
        .select('*, pf_categories(name, icon, color)')
        .single();

    final tx = TransactionModel.fromJson(res);

    // If expense with category, update spent_amount in pf_monthly_budgets
    if (type == TransactionType.expense && categoryId != null) {
      final month = transactionDate.month;
      final year = transactionDate.year;

      final budgetRes = await _client
          .from('pf_monthly_budgets')
          .select('id, spent_amount')
          .eq('user_id', _userId)
          .eq('category_id', categoryId)
          .eq('period_month', month)
          .eq('period_year', year)
          .maybeSingle();

      if (budgetRes != null) {
        final currentSpent = (budgetRes['spent_amount'] as num?)?.toInt() ?? 0;
        await _client
            .from('pf_monthly_budgets')
            .update({'spent_amount': currentSpent + amount})
            .eq('id', budgetRes['id']);
      }
    }

    return tx;
  }

  /// Delete transaction
  Future<void> deleteTransaction(String id) async {
    await _client
        .from('pf_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
