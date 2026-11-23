// lib/features/splits/presentation/providers/splits_provider.dart
//
// Pencatatan patungan:
// * Bagian saya  -> pengeluaran biasa (masuk budget kategori).
// * Bagian teman -> transfer keluar dari dompet ("talangan"), tidak dihitung
//   sebagai pengeluaran, karena uangnya akan kembali.
// * Teman melunasi -> transfer masuk ke dompet yang dipilih.
// Dengan begitu saldo dompet akurat dan budget tidak terdistorsi.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/split_repository.dart';
import '../../domain/split_bill.dart';

final splitRepositoryProvider = Provider<SplitRepository>((ref) {
  return SplitRepository(ref.watch(supabaseClientProvider));
});

final splitsProvider = AsyncNotifierProvider<SplitsNotifier, List<SplitBill>>(
  SplitsNotifier.new,
);

class SplitsNotifier extends AsyncNotifier<List<SplitBill>> {
  @override
  Future<List<SplitBill>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    try {
      return await ref.watch(splitRepositoryProvider).getSplits();
    } catch (_) {
      return const [];
    }
  }

  Future<void> create({
    required String title,
    required int totalAmount,
    required int myShare,
    required DateTime date,
    String? walletId,
    String? categoryId,
    required List<({String name, int share})> participants,
  }) async {
    final txs = ref.read(transactionsProvider.notifier);
    String? myTxId;
    if (myShare > 0) {
      await txs.addTransaction(
        categoryId: categoryId,
        type: TransactionType.expense,
        amount: myShare,
        transactionDate: date,
        description: 'Patungan: $title (bagianku)',
        merchant: title,
        walletId: walletId,
        source: 'split',
      );
      myTxId = ref.read(transactionsProvider).value?.firstOrNull?.id;
    }
    final fronted = totalAmount - myShare;
    if (fronted > 0) {
      await txs.addTransaction(
        type: TransactionType.transfer,
        amount: fronted,
        transactionDate: date,
        description: 'Talangan patungan: $title',
        walletId: walletId,
        source: 'split',
      );
    }
    await ref
        .read(splitRepositoryProvider)
        .create(
          title: title,
          totalAmount: totalAmount,
          myShare: myShare,
          date: date,
          walletId: walletId,
          categoryId: categoryId,
          transactionId: myTxId != null && !myTxId.startsWith('local-')
              ? myTxId
              : null,
          participants: participants,
        );
    ref.invalidateSelf();
  }

  Future<void> settle(
    SplitBill bill,
    SplitParticipant p, {
    String? toWalletId,
  }) async {
    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          type: TransactionType.transfer,
          amount: p.shareAmount,
          transactionDate: DateTime.now(),
          description: 'Pelunasan patungan: ${bill.title} dari ${p.name}',
          toWalletId: toWalletId ?? bill.walletId,
          source: 'split',
        );
    final txId = ref.read(transactionsProvider).value?.firstOrNull?.id;
    await ref
        .read(splitRepositoryProvider)
        .markSettled(
          p.id,
          transactionId: txId != null && !txId.startsWith('local-')
              ? txId
              : null,
        );
    ref.invalidateSelf();
  }

  Future<void> delete(SplitBill bill) async {
    await ref.read(splitRepositoryProvider).delete(bill.id);
    state = AsyncValue.data(
      (state.value ?? []).where((s) => s.id != bill.id).toList(),
    );
  }
}

/// Total piutang patungan yang belum kembali.
final splitReceivableProvider = Provider<int>((ref) {
  return (ref.watch(splitsProvider).value ?? const []).fold<int>(
    0,
    (s, b) => s + b.outstanding,
  );
});
