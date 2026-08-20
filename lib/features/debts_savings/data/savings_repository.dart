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
        .order('is_completed')
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
      'is_completed': currentAmount >= targetAmount,
    };
    if (targetDate != null) {
      map['target_date'] = targetDate.toIso8601String().split('T').first;
    }
    if (icon != null) map['icon'] = icon;
    if (color != null) map['color'] = color;

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
      'savings_goal_id': savingsGoalId,
      'user_id': _userId,
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T').first,
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
    final targetAmount = (goalRes['target_amount'] as num).toInt();

    final delta = type == SavingsTransactionType.deposit ? amount : -amount;
    final int newAmount = (curAmount + delta) > 0 ? (curAmount + delta) : 0;

    await _client.from('pf_savings_goals').update({
      'current_amount': newAmount,
      'is_completed': newAmount >= targetAmount,
    }).eq('id', savingsGoalId);
  }

  /// Get transaction history for a goal
  Future<List<SavingsTransaction>> getSavingsTransactions(String goalId) async {
    final res = await _client
        .from('pf_savings_transactions')
        .select()
        .eq('savings_goal_id', goalId)
        .order('transaction_date', ascending: false);
    return (res as List)
        .map((json) => SavingsTransaction.fromJson(json))
        .toList();
  }
}
