// lib/features/debts_savings/data/savings_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/savings_goal.dart';
import '../domain/savings_transaction.dart';

class SavingsRepository {
  final SupabaseClient _client;

  SavingsRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch savings goals and emergency fund
  Future<List<SavingsGoal>> getSavingsGoals() async {
    final res = await _client
        .from('pf_savings_goals')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return (res as List).map((json) => SavingsGoal.fromJson(json)).toList();
  }

  /// Create savings goal or emergency fund target
  Future<SavingsGoal> createSavingsGoal({
    required String name,
    required GoalType goalType,
    required int targetAmount,
    int currentAmount = 0,
    DateTime? targetDate,
    String? icon,
    String? color,
  }) async {
    final map = <String, dynamic>{
      'user_id': _userId,
      'name': name.trim(),
      'goal_type': goalType.toDbString(),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'is_active': true,
    };
    if (targetDate != null) {
      map['target_date'] = targetDate.toIso8601String().split('T').first;
    }

    final res =
        await _client.from('pf_savings_goals').insert(map).select().single();
    return SavingsGoal.fromJson(res);
  }

  /// Record a deposit or withdrawal to a savings goal
  Future<void> recordSavingsTransaction({
    required String savingsGoalId,
    required SavingsTransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? note,
  }) async {
    final txMap = <String, dynamic>{
      'goal_id': savingsGoalId,
      'user_id': _userId,
      'type': type.toDbString(),
      'amount': amount,
    };
    if (note != null) txMap['note'] = note.trim();

    await _client.from('pf_savings_transactions').insert(txMap);

    // Update current_amount in pf_savings_goals
    final goalRes = await _client
        .from('pf_savings_goals')
        .select('current_amount, target_amount')
        .eq('id', savingsGoalId)
        .single();
    final curAmount = (goalRes['current_amount'] as num).toInt();

    final delta = type == SavingsTransactionType.deposit ? amount : -amount;
    final int newAmount = (curAmount + delta) > 0 ? (curAmount + delta) : 0;

    await _client.from('pf_savings_goals').update({
      'current_amount': newAmount,
    }).eq('id', savingsGoalId);
  }

  /// Get transaction history for a goal
  Future<List<SavingsTransaction>> getSavingsTransactions(String goalId) async {
    final res = await _client
        .from('pf_savings_transactions')
        .select()
        .eq('goal_id', goalId)
        .order('created_at', ascending: false);
    return (res as List)
        .map((json) => SavingsTransaction.fromJson(json))
        .toList();
  }

  /// Delete a savings goal and cleanly remove related auto-synced transactions
  Future<void> deleteSavingsGoal(String goalId) async {
    // 1. Fetch goal name to match auto-generated transactions
    final goalRes = await _client
        .from('pf_savings_goals')
        .select('name')
        .eq('id', goalId)
        .eq('user_id', _userId)
        .maybeSingle();

    final goalName = goalRes != null ? goalRes['name'] as String? : null;

    // 2. Delete from pf_savings_transactions
    await _client
        .from('pf_savings_transactions')
        .delete()
        .eq('goal_id', goalId)
        .eq('user_id', _userId);

    // 3. Delete from pf_savings_goals
    await _client
        .from('pf_savings_goals')
        .delete()
        .eq('id', goalId)
        .eq('user_id', _userId);

    // 4. Clean up auto-synced transactions from pf_transactions if goalName is known
    if (goalName != null && goalName.trim().isNotEmpty) {
      final pattern = 'Setor: $goalName%';
      final txs = await _client
          .from('pf_transactions')
          .select('id, category_id, amount, transaction_date')
          .eq('user_id', _userId)
          .ilike('note', pattern);

      for (final tx in (txs as List)) {
        final txId = tx['id'] as String;
        final catId = tx['category_id'] as String?;
        final amt = (tx['amount'] as num).toInt();
        final dt = DateTime.parse(tx['transaction_date'] as String);

        await _client
            .from('pf_transactions')
            .delete()
            .eq('id', txId)
            .eq('user_id', _userId);

        if (catId != null) {
          await _adjustBudgetSpent(
            categoryId: catId,
            month: dt.month,
            year: dt.year,
            delta: -amt,
          );
        }
      }
    }
  }

  /// Clean up orphaned tabungan records (e.g. 150k phantom savings) and recalibrate budget spent_amount
  Future<void> cleanupPhantomSavingsAndRecalibrate({int targetAmount = 150000}) async {
    try {
      // 1. Delete matching pf_savings_transactions with targetAmount (150,000)
      await _client
          .from('pf_savings_transactions')
          .delete()
          .eq('user_id', _userId)
          .eq('amount', targetAmount);

      // 2. Find and delete matching pf_transactions with targetAmount
      final txRes = await _client
          .from('pf_transactions')
          .select('id, category_id, transaction_date, note, pf_categories(name, type)')
          .eq('user_id', _userId)
          .eq('amount', targetAmount);

      for (final t in (txRes as List)) {
        final cat = t['pf_categories'] as Map<String, dynamic>?;
        final catType = (cat != null ? (cat['type'] as String? ?? '') : '').toLowerCase();
        final catName = (cat != null ? (cat['name'] as String? ?? '') : '').toLowerCase();
        final note = (t['note'] as String? ?? '').toLowerCase();

        final isSavingsTx = catType == 'saving' ||
            catType == 'savings' ||
            catName.contains('tabung') ||
            catName.contains('saving') ||
            catName.contains('darurat') ||
            note.contains('setor') ||
            note.contains('tabung');

        if (isSavingsTx) {
          final txId = t['id'] as String;
          await _client
              .from('pf_transactions')
              .delete()
              .eq('id', txId)
              .eq('user_id', _userId);
        }
      }

      // 3. Recalibrate monthly budgets spent_amount for current and nearby months
      final now = DateTime.now();
      for (final period in [
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month - 1, 1),
      ]) {
        await recalibrateMonthlyBudgets(month: period.month, year: period.year);
      }
    } catch (_) {}
  }

  /// Recalibrate all spent_amounts in pf_monthly_budgets to match actual transactions
  Future<void> recalibrateMonthlyBudgets({required int month, required int year}) async {
    try {
      final budgetsRes = await _client
          .from('pf_monthly_budgets')
          .select('id, category_id')
          .eq('user_id', _userId)
          .eq('period_month', month)
          .eq('period_year', year);

      final startStr = DateTime(year, month, 1).toIso8601String().split('T').first;
      final endStr = (month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1))
          .toIso8601String()
          .split('T')
          .first;

      final txRes = await _client
          .from('pf_transactions')
          .select('category_id, amount')
          .eq('user_id', _userId)
          .eq('type', 'expense')
          .gte('transaction_date', startStr)
          .lt('transaction_date', endStr);

      final Map<String, int> actualSpentByCat = {};
      for (final t in (txRes as List)) {
        final cid = t['category_id'] as String?;
        if (cid != null) {
          final amt = (t['amount'] as num).toInt();
          actualSpentByCat[cid] = (actualSpentByCat[cid] ?? 0) + amt;
        }
      }

      for (final b in (budgetsRes as List)) {
        final bid = b['id'] as String;
        final cid = b['category_id'] as String;
        final actual = actualSpentByCat[cid] ?? 0;
        await _client
            .from('pf_monthly_budgets')
            .update({'spent_amount': actual})
            .eq('id', bid);
      }
    } catch (_) {}
  }

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
