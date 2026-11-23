// lib/features/insights/presentation/providers/history_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

/// Transaksi 4 bulan terakhir (termasuk bulan berjalan). Dipakai untuk
/// insight bulanan dan deteksi langganan.
final recentHistoryProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  // Ikut diperbarui setiap kali transaksi bulan aktif berubah.
  ref.watch(transactionsProvider.select((v) => v.value?.length));
  final now = DateTime.now();
  try {
    return await ref
        .read(transactionRepositoryProvider)
        .getTransactionsBetween(
          start: DateTime(now.year, now.month - 3, 1),
          endExclusive: DateTime(now.year, now.month + 1, 1),
        );
  } catch (_) {
    return ref.read(transactionsProvider).value ?? const [];
  }
});
