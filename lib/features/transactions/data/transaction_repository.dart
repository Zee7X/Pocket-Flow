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

  /// Create a transaction and sync monthly budget spent_amount
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
    if (description != null) map['note'] = description.trim();

    final res = await _client
        .from('pf_transactions')
        .insert(map)
        .select('*, pf_categories(name, icon, color)')
        .single();

    final tx = TransactionModel.fromJson(res);

    // If expense with category, add to spent_amount in pf_monthly_budgets
    if (type == TransactionType.expense && categoryId != null) {
      await _adjustBudgetSpent(
        categoryId: categoryId,
        month: transactionDate.month,
        year: transactionDate.year,
        delta: amount,
      );
    }

    return tx;
  }

  /// Update existing transaction and recalibrate monthly budget spent_amount
  Future<TransactionModel> updateTransaction({
    required String id,
    String? categoryId,
    required TransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? description,
    String? paymentMethod,
  }) async {
    // 1. Fetch old transaction before update
    final oldRes = await _client
        .from('pf_transactions')
        .select('category_id, type, amount, transaction_date')
        .eq('id', id)
        .single();

    final oldCatId = oldRes['category_id'] as String?;
    final oldType = (oldRes['type'] as String) == 'expense'
        ? TransactionType.expense
        : TransactionType.income;
    final oldAmount = (oldRes['amount'] as num).toInt();
    final oldDate = DateTime.parse(oldRes['transaction_date'] as String);

    // 2. Perform update
    final map = <String, dynamic>{
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
      'category_id': categoryId,
    };
    if (description != null) map['note'] = description.trim();

    final res = await _client
        .from('pf_transactions')
        .update(map)
        .eq('id', id)
        .select('*, pf_categories(name, icon, color)')
        .single();

    final updatedTx = TransactionModel.fromJson(res);

    // 3. Recalibrate budget spent_amount
    // Revert old expense if applicable
    if (oldType == TransactionType.expense && oldCatId != null) {
      await _adjustBudgetSpent(
        categoryId: oldCatId,
        month: oldDate.month,
        year: oldDate.year,
        delta: -oldAmount,
      );
    }
    // Apply new expense if applicable
    if (type == TransactionType.expense && categoryId != null) {
      await _adjustBudgetSpent(
        categoryId: categoryId,
        month: transactionDate.month,
        year: transactionDate.year,
        delta: amount,
      );
    }

    return updatedTx;
  }

  /// Delete transaction and adjust budget spent_amount
  Future<void> deleteTransaction(String id) async {
    // 1. Fetch transaction before deleting
    final txRes = await _client
        .from('pf_transactions')
        .select('category_id, type, amount, transaction_date')
        .eq('id', id)
        .maybeSingle();

    if (txRes != null) {
      final catId = txRes['category_id'] as String?;
      final typeStr = txRes['type'] as String;
      final amount = (txRes['amount'] as num).toInt();
      final date = DateTime.parse(txRes['transaction_date'] as String);

      // If it was an expense, subtract from monthly budget spent_amount
      if (typeStr == 'expense' && catId != null) {
        await _adjustBudgetSpent(
          categoryId: catId,
          month: date.month,
          year: date.year,
          delta: -amount,
        );
      }
    }

    // 2. Delete from pf_transactions
    await _client
        .from('pf_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Helper to safely increment or decrement budget spent_amount
  Future<void> _adjustBudgetSpent({
    required String categoryId,
    required int month,
    required int year,
    required int delta,
  }) async {
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
      final int newSpent = (currentSpent + delta) > 0 ? (currentSpent + delta) : 0;
      await _client
          .from('pf_monthly_budgets')
          .update({'spent_amount': newSpent})
          .eq('id', budgetRes['id']);
    }
  }
}
