// lib/features/debts_savings/presentation/providers/debts_savings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/debt_repository.dart';
import '../../data/savings_repository.dart';
import '../../domain/debt.dart';
import '../../domain/savings_goal.dart';
import '../../domain/savings_transaction.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../../../features/reports/presentation/providers/reports_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';

// ─── Repositories ────────────────────────────────────────────────────────────
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository(ref.watch(supabaseClientProvider));
});

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository(ref.watch(supabaseClientProvider));
});

// ─── Debts State ─────────────────────────────────────────────────────────────
final debtsProvider = AsyncNotifierProvider<DebtsNotifier, List<Debt>>(
  DebtsNotifier.new,
);

class DebtsNotifier extends AsyncNotifier<List<Debt>> {
  @override
  Future<List<Debt>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.watch(debtRepositoryProvider).getDebts();
  }

  Future<void> addDebt({
    required String name,
    required DebtType debtType,
    required int totalAmount,
    required int remainingAmount,
    int minimumPayment = 0,
    int? interestRate,
    int? dueDay,
  }) async {
    final newDebt = await ref.read(debtRepositoryProvider).createDebt(
          name: name,
          debtType: debtType,
          totalAmount: totalAmount,
          remainingAmount: remainingAmount,
          minimumPayment: minimumPayment,
          interestRate: interestRate,
          dueDay: dueDay,
        );
    state = AsyncValue.data([...(state.value ?? []), newDebt]);
  }

  Future<void> recordPayment({
    required String debtId,
    required int amount,
    required DateTime paymentDate,
    String? note,
  }) async {
    await ref.read(debtRepositoryProvider).recordPayment(
          debtId: debtId,
          amount: amount,
          paymentDate: paymentDate,
          note: note,
        );
    // Refresh debts list in-place
    final freshDebts = await ref.read(debtRepositoryProvider).getDebts();
    state = AsyncValue.data(freshDebts);
  }

  Future<void> deleteDebt(String debtId) async {
    await ref.read(debtRepositoryProvider).deleteDebt(debtId);
    state = AsyncValue.data(
      (state.value ?? []).where((d) => d.id != debtId).toList(),
    );
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyBudgetsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(dashboardSummaryProvider);
  }
}

// ─── Savings Goals State ─────────────────────────────────────────────────────
final savingsGoalsProvider =
    AsyncNotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(
  SavingsGoalsNotifier.new,
);

class SavingsGoalsNotifier extends AsyncNotifier<List<SavingsGoal>> {
  @override
  Future<List<SavingsGoal>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.watch(savingsRepositoryProvider).getSavingsGoals();
  }

  Future<void> addSavingsGoal({
    required String name,
    required GoalType goalType,
    required int targetAmount,
    int currentAmount = 0,
    DateTime? targetDate,
    String? icon,
    String? color,
  }) async {
    final newGoal = await ref.read(savingsRepositoryProvider).createSavingsGoal(
          name: name,
          goalType: goalType,
          targetAmount: targetAmount,
          currentAmount: currentAmount,
          targetDate: targetDate,
          icon: icon,
          color: color,
        );
    state = AsyncValue.data([...(state.value ?? []), newGoal]);
  }

  Future<void> recordSavingsTransaction({
    required String savingsGoalId,
    required SavingsTransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? note,
  }) async {
    await ref.read(savingsRepositoryProvider).recordSavingsTransaction(
          savingsGoalId: savingsGoalId,
          type: type,
          amount: amount,
          transactionDate: transactionDate,
          note: note,
        );
    // Refresh savings goals list in-place
    final freshGoals =
        await ref.read(savingsRepositoryProvider).getSavingsGoals();
    state = AsyncValue.data(freshGoals);
  }

  Future<void> deleteSavingsGoal(String goalId) async {
    await ref.read(savingsRepositoryProvider).deleteSavingsGoal(goalId);
    state = AsyncValue.data(
      (state.value ?? []).where((g) => g.id != goalId).toList(),
    );
    ref.invalidate(transactionsProvider);
    ref.invalidate(monthlyBudgetsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(dashboardSummaryProvider);
  }
}
