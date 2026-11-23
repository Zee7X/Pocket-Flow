// lib/features/smart/data/merchant_rule_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantRuleRepository {
  final SupabaseClient _client;
  MerchantRuleRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// merchantKey -> categoryId
  Future<Map<String, String>> getRules() async {
    final res = await _client
        .from('pf_merchant_rules')
        .select('merchant_key, category_id')
        .eq('user_id', _userId);
    return {
      for (final r in (res as List))
        if (r['category_id'] != null)
          r['merchant_key'] as String: r['category_id'] as String,
    };
  }

  /// Simpan / perbarui aturan "merchant ini selalu kategori X".
  Future<void> learn({
    required String merchantKey,
    required String categoryId,
    String? walletId,
  }) async {
    if (merchantKey.isEmpty) return;
    await _client.from('pf_merchant_rules').upsert({
      'user_id': _userId,
      'merchant_key': merchantKey,
      'category_id': categoryId,
      'wallet_id': walletId,
    }, onConflict: 'user_id,merchant_key');
  }
}
