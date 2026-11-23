// lib/features/smart/presentation/providers/smart_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../data/merchant_rule_repository.dart';
import '../../domain/category_suggester.dart';

final merchantRuleRepositoryProvider = Provider<MerchantRuleRepository>((ref) {
  return MerchantRuleRepository(ref.watch(supabaseClientProvider));
});

final merchantRulesProvider =
    AsyncNotifierProvider<MerchantRulesNotifier, Map<String, String>>(
      MerchantRulesNotifier.new,
    );

class MerchantRulesNotifier extends AsyncNotifier<Map<String, String>> {
  @override
  Future<Map<String, String>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const {};
    try {
      return await ref.watch(merchantRuleRepositoryProvider).getRules();
    } catch (_) {
      return const {};
    }
  }

  /// Dipanggil setiap kali pengguna menyimpan transaksi dengan merchant +
  /// kategori. Transaksi berikutnya dari merchant yang sama otomatis
  /// mendapat kategori ini.
  Future<void> learn(
    String? merchant,
    String? categoryId, {
    String? walletId,
  }) async {
    if (merchant == null || categoryId == null) return;
    final key = merchantKey(merchant);
    if (key.isEmpty) return;
    final current = state.value ?? const {};
    if (current[key] == categoryId) return;
    state = AsyncValue.data({...current, key: categoryId});
    try {
      await ref
          .read(merchantRuleRepositoryProvider)
          .learn(merchantKey: key, categoryId: categoryId, walletId: walletId);
    } catch (_) {}
  }
}

final categorySuggesterProvider = Provider<CategorySuggester>((ref) {
  return CategorySuggester(
    userRules: ref.watch(merchantRulesProvider).value ?? const {},
    categories: ref.watch(categoriesProvider).value ?? const [],
  );
});
