// lib/features/dashboard/presentation/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_flow/features/salary_allocation/domain/monthly_budget.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';
import 'package:pocket_flow/features/transactions/presentation/providers/transactions_provider.dart';

class DashboardSummary {
  final int totalAllocated;
  final int totalSpent;
  final int remainingBudget;
  final int safeSpendingToday;
  final int daysRemainingInMonth;
  final int totalDaysInMonth;
  final List<MonthlyBudget> categoryBudgets;
  final List<TransactionModel> recentTransactions;
  final bool hasSalaryEntry;

  const DashboardSummary({
    required this.totalAllocated,
    required this.totalSpent,
    required this.remainingBudget,
    required this.safeSpendingToday,
    required this.daysRemainingInMonth,
    required this.totalDaysInMonth,
    required this.categoryBudgets,
    required this.recentTransactions,
    required this.hasSalaryEntry,
  });
}

final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final budgetsAsync = ref.watch(monthlyBudgetsProvider);
  final txAsync = ref.watch(transactionsProvider);

  if (budgetsAsync.isLoading || txAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (budgetsAsync.hasError) {
    return AsyncValue.error(budgetsAsync.error!, budgetsAsync.stackTrace!);
  }
  if (txAsync.hasError) {
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);
  }

  final budgets = budgetsAsync.value ?? [];
  final transactions = txAsync.value ?? [];

  final now = DateTime.now();
  final period = ref.watch(selectedPeriodProvider);

  // Total days in month
  final lastDayOfMonth = DateTime(period.year, period.month + 1, 0).day;
  final int currentDay = (period.month == now.month && period.year == now.year)
      ? now.day
      : 1;
  final int daysRemaining =
      (lastDayOfMonth - currentDay + 1).clamp(1, lastDayOfMonth);

  // Calculate totals
  int totalAllocated = 0;
  int totalSpent = 0;

  for (final b in budgets) {
    totalAllocated += b.allocatedAmount;
    totalSpent += b.spentAmount;
  }

  final int remaining = (totalAllocated - totalSpent) > 0 ? (totalAllocated - totalSpent) : 0;
  final int safeSpending =
      daysRemaining > 0 ? (remaining / daysRemaining).floor() : 0;

  return AsyncValue.data(
    DashboardSummary(
      totalAllocated: totalAllocated,
      totalSpent: totalSpent,
      remainingBudget: remaining,
      safeSpendingToday: safeSpending,
      daysRemainingInMonth: daysRemaining,
      totalDaysInMonth: lastDayOfMonth,
      categoryBudgets: budgets,
      recentTransactions: transactions.take(5).toList(),
      hasSalaryEntry: budgets.isNotEmpty,
    ),
  );
});
