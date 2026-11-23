// lib/features/wallets/data/wallet_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/wallet.dart';

class WalletRepository {
  final SupabaseClient _client;
  WalletRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  Future<List<Wallet>> getWallets() async {
    final rows = await _client
        .from('pf_wallets')
        .select()
        .eq('user_id', _userId)
        .eq('is_archived', false)
        .order('sort_order')
        .order('created_at');
    final balances = await _client
        .from('pf_wallet_balances')
        .select('wallet_id, balance')
        .eq('user_id', _userId);
    final byId = <String, int>{
      for (final b in (balances as List))
        b['wallet_id'] as String: (b['balance'] as num?)?.toInt() ?? 0,
    };
    return (rows as List)
        .map((j) => Wallet.fromJson(j, balance: byId[j['id']]))
        .toList();
  }

  Future<Wallet> createWallet({
    required String name,
    required WalletKind kind,
    String? providerKey,
    int initialBalance = 0,
    String? color,
    int sortOrder = 0,
  }) async {
    final res = await _client
        .from('pf_wallets')
        .insert({
          'user_id': _userId,
          'name': name.trim(),
          'kind': kind.name,
          'provider_key': providerKey,
          'initial_balance': initialBalance,
          'color': color,
          'sort_order': sortOrder,
        })
        .select()
        .single();
    return Wallet.fromJson(res);
  }

  Future<void> updateWallet({
    required String id,
    required String name,
    required WalletKind kind,
    String? providerKey,
    required int initialBalance,
    String? color,
  }) async {
    await _client
        .from('pf_wallets')
        .update({
          'name': name.trim(),
          'kind': kind.name,
          'provider_key': providerKey,
          'initial_balance': initialBalance,
          'color': color,
        })
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Dompet diarsipkan (bukan dihapus) supaya riwayat transaksi tetap utuh.
  Future<void> archiveWallet(String id) async {
    await _client
        .from('pf_wallets')
        .update({'is_archived': true})
        .eq('id', id)
        .eq('user_id', _userId);
  }
}
