// lib/features/debts_savings/data/debt_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/debt.dart';
import '../domain/debt_payment.dart';

class DebtRepository {
  final SupabaseClient _client;

  DebtRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch active debts
  Future<List<Debt>> getDebts() async {
    final res = await _client
        .from('pf_debts')
        .select()
        .eq('user_id', _userId)
        .order('status')
        .order('remaining_amount', ascending: false);
    return (res as List).map((json) => Debt.fromJson(json)).toList();
  }

  /// Create a new debt item
  Future<Debt> createDebt({
    required String name,
    required DebtType debtType,
    required int totalAmount,
    required int remainingAmount,
    int minimumPayment = 0,
    int? interestRate,
    int? dueDay,
  }) async {
    final map = <String, dynamic>{
      'user_id': _userId,
      'name': name.trim(),
      'initial_amount': totalAmount,
      'remaining_amount': remainingAmount,
      'minimum_payment': minimumPayment,
      'status': remainingAmount <= 0 ? 'paid' : 'active',
      'note': debtType.toDbString(),
    };

    final res = await _client.from('pf_debts').insert(map).select().single();
    return Debt.fromJson(res);
  }

  /// Record payment for a debt
  Future<void> recordPayment({
    required String debtId,
    required int amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    final paymentMap = <String, dynamic>{
      'debt_id': debtId,
      'user_id': _userId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String().split('T').first,
    };
    if (note != null) paymentMap['note'] = note.trim();

    await _client.from('pf_debt_payments').insert(paymentMap);

    // Reduce remaining_amount in pf_debts
    final debtRes = await _client
        .from('pf_debts')
        .select('remaining_amount')
        .eq('id', debtId)
        .single();
    final curRemaining = (debtRes['remaining_amount'] as num).toInt();
    final newRemaining = (curRemaining - amount) > 0 ? (curRemaining - amount) : 0;

    await _client.from('pf_debts').update({
      'remaining_amount': newRemaining,
      'status': newRemaining <= 0 ? 'paid' : 'active',
    }).eq('id', debtId);
  }

  /// Fetch payment history for a debt
  Future<List<DebtPayment>> getPayments(String debtId) async {
    final res = await _client
        .from('pf_debt_payments')
        .select()
        .eq('debt_id', debtId)
        .order('payment_date', ascending: false);
    return (res as List).map((json) => DebtPayment.fromJson(json)).toList();
  }

  /// Delete a debt item
  Future<void> deleteDebt(String debtId) async {
    await _client
        .from('pf_debt_payments')
        .delete()
        .eq('debt_id', debtId)
        .eq('user_id', _userId);
    await _client
        .from('pf_debts')
        .delete()
        .eq('id', debtId)
        .eq('user_id', _userId);
  }
}
