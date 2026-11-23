// lib/features/splits/data/split_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/split_bill.dart';

class SplitRepository {
  final SupabaseClient _client;
  SplitRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<SplitBill>> getSplits() async {
    final res = await _client
        .from('pf_splits')
        .select('*, pf_split_participants(*)')
        .eq('user_id', _userId)
        .order('split_date', ascending: false)
        .limit(100);
    return (res as List).map((j) => SplitBill.fromJson(j)).toList();
  }

  Future<void> create({
    required String title,
    required int totalAmount,
    required int myShare,
    required DateTime date,
    String? walletId,
    String? categoryId,
    String? transactionId,
    required List<({String name, int share})> participants,
  }) async {
    final split = await _client
        .from('pf_splits')
        .insert({
          'user_id': _userId,
          'title': title.trim(),
          'total_amount': totalAmount,
          'my_share': myShare,
          'split_date': date.toIso8601String().split('T').first,
          'wallet_id': walletId,
          'category_id': categoryId,
          'transaction_id': transactionId,
        })
        .select('id')
        .single();
    if (participants.isEmpty) return;
    await _client.from('pf_split_participants').insert([
      for (final p in participants)
        {
          'user_id': _userId,
          'split_id': split['id'],
          'name': p.name.trim(),
          'share_amount': p.share,
        },
    ]);
  }

  Future<void> markSettled(
    String participantId, {
    String? transactionId,
  }) async {
    await _client
        .from('pf_split_participants')
        .update({
          'is_settled': true,
          'settled_at': DateTime.now().toUtc().toIso8601String(),
          'settled_transaction_id': transactionId,
        })
        .eq('id', participantId)
        .eq('user_id', _userId);
  }

  Future<void> delete(String splitId) async {
    await _client
        .from('pf_splits')
        .delete()
        .eq('id', splitId)
        .eq('user_id', _userId);
  }
}
