// lib/features/capture/data/pending_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../transactions/domain/transaction.dart';
import '../domain/pending_capture.dart';

class PendingRepository {
  final SupabaseClient _client;
  PendingRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<PendingCapture>> getPending() async {
    final res = await _client
        .from('pf_pending_transactions')
        .select()
        .eq('user_id', _userId)
        .eq('status', 'pending')
        .order('occurred_at', ascending: false)
        .limit(200);
    return (res as List).map((j) => PendingCapture.fromJson(j)).toList();
  }

  /// Insert; baris dengan dedupe_hash yang sama diabaikan.
  Future<void> insertMany(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _client
        .from('pf_pending_transactions')
        .upsert(
          [
            for (final r in rows) {...r, 'user_id': _userId},
          ],
          onConflict: 'user_id,dedupe_hash',
          ignoreDuplicates: true,
        );
  }

  Future<void> markTransfer({
    required String id,
    required String? fromWalletId,
    required String? toWalletId,
    required int amount,
  }) async {
    await _client
        .from('pf_pending_transactions')
        .update({
          'type': TransactionType.transfer.toDbString(),
          'suggested_wallet_id': fromWalletId,
          'to_wallet_id': toWalletId,
          'amount': amount,
          'suggested_category_id': null,
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<void> setStatus(
    String id,
    String status, {
    String? transactionId,
  }) async {
    await _client
        .from('pf_pending_transactions')
        .update({'status': status, 'transaction_id': ?transactionId})
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
