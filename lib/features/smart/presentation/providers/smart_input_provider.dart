// lib/features/smart/presentation/providers/smart_input_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../data/ai_parse_service.dart';
import '../../domain/quick_text_parser.dart';
import 'smart_providers.dart';

final aiParseServiceProvider = Provider<AiParseService>((ref) {
  return AiParseService(ref.watch(supabaseClientProvider));
});

/// Lengkapi draft: dompet dari nama penyedia, kategori dari aturan/kata kunci
/// bila AI tidak mengisinya.
final draftEnricherProvider =
    Provider<List<DraftTransaction> Function(List<DraftTransaction>)>((ref) {
      final wallets = ref.watch(walletsProvider).value ?? const [];
      final suggester = ref.watch(categorySuggesterProvider);
      final categories = ref.watch(categoriesProvider).value ?? const [];

      String? walletFor(String? providerKey) => providerKey == null
          ? null
          : wallets.where((w) => w.providerKey == providerKey).firstOrNull?.id;

      return (drafts) => [
        for (final d in drafts)
          () {
            final validCat =
                d.categoryId != null &&
                categories.any((c) => c.id == d.categoryId);
            final cat = d.type == TransactionType.transfer
                ? null
                : (validCat
                      ? d.categoryId
                      : suggester
                            .suggest(
                              merchant: d.merchant ?? d.note,
                              isIncome: d.type == TransactionType.income,
                            )
                            ?.categoryId);
            return d.copyWith(
              categoryId: cat,
              clearCategory: cat == null,
              walletId: d.walletId ?? walletFor(d.providerKey),
              toWalletId: d.toWalletId ?? walletFor(d.toProviderKey),
            );
          }(),
      ];
    });
