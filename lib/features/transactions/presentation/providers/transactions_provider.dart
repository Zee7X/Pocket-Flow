// lib/features/transactions/presentation/providers/transactions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../data/transaction_repository.dart';
import '../../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

// Transactions list for selected month/year
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    final period = ref.watch(selectedPeriodProvider);
    return ref.watch(transactionRepositoryProvider).getTransactions(
          month: period.month,
          year: period.year,
        );
  }

  Future<void> addTransaction({
    String? categoryId,
    required TransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? description,
    String? paymentMethod,
  }) async {
    final newTx =
        await ref.read(transactionRepositoryProvider).createTransaction(
              categoryId: categoryId,
              type: type,
              amount: amount,
              transactionDate: transactionDate,
              description: description,
              paymentMethod: paymentMethod,
            );

    // In-place update to prevent full page reload / spinner
    state = AsyncValue.data([newTx, ...(state.value ?? [])]);

    // Invalidate monthly budgets to reflect newly spent budget
    ref.invalidate(monthlyBudgetsProvider);
  }

  Future<void> deleteTransaction(String id) async {
    await ref.read(transactionRepositoryProvider).deleteTransaction(id);

    // In-place remove
    state = AsyncValue.data(
      (state.value ?? []).where((t) => t.id != id).toList(),
    );

    // Invalidate monthly budgets to reflect restored budget
    ref.invalidate(monthlyBudgetsProvider);
  }
}
