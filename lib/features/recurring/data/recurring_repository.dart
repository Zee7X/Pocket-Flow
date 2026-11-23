// lib/features/recurring/data/recurring_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/recurring_bill.dart';

class RecurringRepository {
  final SupabaseClient _client;
  RecurringRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;
  static String _d(DateTime d) => d.toIso8601String().split('T').first;

  Future<List<RecurringBill>> getBills() async {
    final res = await _client
        .from('pf_recurring_bills')
        .select()
        .eq('user_id', _userId)
        .eq('is_active', true)
        .order('next_due_date');
    return (res as List).map((j) => RecurringBill.fromJson(j)).toList();
  }

  Future<RecurringBill> upsert({
    String? id,
    required String name,
    required int amount,
    String? categoryId,
    String? walletId,
    String? debtId,
    required BillCadence cadence,
    required DateTime nextDueDate,
    int remindDaysBefore = 2,
    String? merchantKey,
  }) async {
    final row = {
      'user_id': _userId,
      'name': name.trim(),
      'amount': amount,
      'category_id': categoryId,
      'wallet_id': walletId,
      'debt_id': debtId,
      'cadence': cadence.name,
      'next_due_date': _d(nextDueDate),
      'remind_days_before': remindDaysBefore,
      'merchant_key': merchantKey,
    };
    final res = id == null
        ? await _client.from('pf_recurring_bills').insert(row).select().single()
        : await _client
              .from('pf_recurring_bills')
              .update(row)
              .eq('id', id)
              .eq('user_id', _userId)
              .select()
              .single();
    return RecurringBill.fromJson(res);
  }

  Future<void> advance(String id, DateTime nextDue) async {
    await _client
        .from('pf_recurring_bills')
        .update({'next_due_date': _d(nextDue)})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> deactivate(String id) async {
    await _client
        .from('pf_recurring_bills')
        .update({'is_active': false})
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
