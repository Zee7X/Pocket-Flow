// lib/features/dashboard/presentation/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_flow/features/salary_allocation/domain/monthly_budget.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';
import 'package:pocket_flow/features/transactions/presentation/providers/transactions_provider.dart';

class CategoryExpenseItem {
  final String categoryId;
  final String categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final int totalAmount;
  final double percentage; // 0.0 to 1.0

  const CategoryExpenseItem({
    required this.categoryId,
    required this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    required this.totalAmount,
    required this.percentage,
  });
}

class DashboardSummary {
  // Real transaction-based cashflow
  final int totalIncome;
  final int totalExpense; // Living / consumption expense
  final int totalSavings; // Money saved
  final int netCashflow; // Income - Expense - Savings

  // Budget Allocation Mode
  final bool hasBudgetAllocation;
  final int totalAllocated; // Total allocated across all budgets
  final int totalBudgetSpent; // Total living expenses spent from budget
  final int totalSavedInBudget; // Total savings fulfilled
  final int remainingBudget;
  final int safeSpendingToday;
  final int totalSpentToday;
  final int variableSpentToday;
  final int dailyQuotaToday;
  final int dailyQuotaTomorrow;
  final Map<String, int> spentTodayByCat;

  // Calendar
  final int daysRemainingInMonth;
  final int totalDaysInMonth;

  // Lists & breakdowns
  final List<MonthlyBudget> categoryBudgets;
  final List<CategoryExpenseItem> categoryExpenses;
  final List<TransactionModel> recentTransactions;

  const DashboardSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.netCashflow,
    required this.hasBudgetAllocation,
    required this.totalAllocated,
    required this.totalBudgetSpent,
    this.totalSavedInBudget = 0,
    required this.remainingBudget,
    required this.safeSpendingToday,
    this.totalSpentToday = 0,
    this.variableSpentToday = 0,
    this.dailyQuotaToday = 0,
    this.dailyQuotaTomorrow = 0,
    this.spentTodayByCat = const {},
    required this.daysRemainingInMonth,
    required this.totalDaysInMonth,
    required this.categoryBudgets,
    required this.categoryExpenses,
    required this.recentTransactions,
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

  // 1. Calculate actual transaction metrics
  int totalIncome = 0;
  int totalExpense = 0;
  int totalSavings = 0;
  int totalSpentToday = 0;
  final Map<String, int> spentTodayByCat = {};
  final Map<String, ({String name, String? icon, String? color, int amount})>
      expenseByCat = {};

  final bool isCurrentPeriod = period.month == now.month && period.year == now.year;

  for (final tx in transactions) {
    final bool isTxToday = isCurrentPeriod &&
        tx.transactionDate.year == now.year &&
        tx.transactionDate.month == now.month &&
        tx.transactionDate.day == now.day;

    if (tx.type == TransactionType.income) {
      totalIncome += tx.amount;
    } else if (tx.type == TransactionType.expense) {
      if (tx.isSavings) {
        totalSavings += tx.amount;
      } else {
        totalExpense += tx.amount;
        if (isTxToday) {
          totalSpentToday += tx.amount;
          final catId = tx.categoryId ?? 'uncategorized';
          spentTodayByCat[catId] = (spentTodayByCat[catId] ?? 0) + tx.amount;
        }
      }
      final catId = tx.categoryId ?? 'uncategorized';
      final catName = tx.categoryName ?? 'Lainnya';
      final prev = expenseByCat[catId];
      if (prev != null) {
        expenseByCat[catId] = (
          name: prev.name,
          icon: prev.icon ?? tx.categoryIcon,
          color: prev.color ?? tx.categoryColor,
          amount: prev.amount + tx.amount,
        );
      } else {
        expenseByCat[catId] = (
          name: catName,
          icon: tx.categoryIcon,
          color: tx.categoryColor,
          amount: tx.amount,
        );
      }
    }
  }

  final netCashflow = totalIncome - totalExpense - totalSavings;

  // Build category expense items (excluding purely savings from living expense breakdown if desired, or marked)
  final categoryExpenses = expenseByCat.entries.map((entry) {
    final pct = totalExpense > 0 ? (entry.value.amount / totalExpense) : 0.0;
    return CategoryExpenseItem(
      categoryId: entry.key,
      categoryName: entry.value.name,
      categoryIcon: entry.value.icon,
      categoryColor: entry.value.color,
      totalAmount: entry.value.amount,
      percentage: pct,
    );
  }).toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

  // 2. Calculate budget allocation metrics
  final bool hasBudgetAllocation = budgets.isNotEmpty;
  int totalAllocated = 0;
  int totalBudgetSpent = 0;
  int totalSavedInBudget = 0;
  int livingBudgetAllocated = 0;

  int safeSpendingToday = 0;
  int variableCategoriesCount = 0;
  int variableSpentToday = 0;
  int dailyQuotaTodaySum = 0;
  int dailyQuotaTomorrowSum = 0;

  for (final b in budgets) {
    totalAllocated += b.allocatedAmount;
    if (b.isSavings) {
      final actualSpent = expenseByCat[b.categoryId]?.amount ?? 0;
      final spent = actualSpent > 0 ? actualSpent : (totalSavings > 0 ? totalSavings : 0);
      totalSavedInBudget += spent;
    } else {
      livingBudgetAllocated += b.allocatedAmount;
      totalBudgetSpent += b.spentAmount;

      if (b.isDailyTrackable) {
        variableCategoriesCount++;
        final int spentToday = spentTodayByCat[b.categoryId] ?? 0;
        variableSpentToday += spentToday;
        final int remainingBeforeToday = b.remainingAmount + spentToday;
        final int dailyQuota = daysRemaining > 0
            ? (remainingBeforeToday / daysRemaining).floor()
            : 0;
        dailyQuotaTodaySum += dailyQuota;

        final int dailyQuotaTomorrow = daysRemaining > 1
            ? (b.remainingAmount / (daysRemaining - 1)).floor()
            : b.remainingAmount;
        dailyQuotaTomorrowSum += dailyQuotaTomorrow;

        final int remainingDailyQuota = (dailyQuota - spentToday).clamp(0, b.remainingAmount);
        safeSpendingToday += remainingDailyQuota;
      }
    }
  }

  final int remainingBudget = hasBudgetAllocation
      ? (livingBudgetAllocated > 0
          ? (livingBudgetAllocated - totalBudgetSpent).clamp(0, 999999999999)
          : (totalAllocated - totalBudgetSpent - totalSavedInBudget).clamp(0, 999999999999))
      : (netCashflow > 0 ? netCashflow : 0);

  // If there are no specifically daily-trackable categories, calculate from overall living budget
  if (variableCategoriesCount == 0 && hasBudgetAllocation) {
    final int livingRemaining = (livingBudgetAllocated - totalBudgetSpent).clamp(0, 999999999999);
    final int livingRemainingBeforeToday = livingRemaining + totalSpentToday;
    final int dailySafeSpendingQuota = daysRemaining > 0
        ? (livingRemainingBeforeToday / daysRemaining).floor()
        : 0;
    dailyQuotaTodaySum = dailySafeSpendingQuota;
    dailyQuotaTomorrowSum = daysRemaining > 1
        ? (livingRemaining / (daysRemaining - 1)).floor()
        : livingRemaining;
    variableSpentToday = totalSpentToday;
    safeSpendingToday = (dailySafeSpendingQuota - totalSpentToday).clamp(0, livingRemaining);
  }

  return AsyncValue.data(
    DashboardSummary(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalSavings: totalSavings,
      netCashflow: netCashflow,
      hasBudgetAllocation: hasBudgetAllocation,
      totalAllocated: totalAllocated,
      totalBudgetSpent: totalBudgetSpent,
      totalSavedInBudget: totalSavedInBudget,
      remainingBudget: remainingBudget,
      safeSpendingToday: safeSpendingToday,
      totalSpentToday: totalSpentToday,
      variableSpentToday: variableSpentToday,
      dailyQuotaToday: dailyQuotaTodaySum,
      dailyQuotaTomorrow: dailyQuotaTomorrowSum,
      spentTodayByCat: spentTodayByCat,
      daysRemainingInMonth: daysRemaining,
      totalDaysInMonth: lastDayOfMonth,
      categoryBudgets: budgets,
      categoryExpenses: categoryExpenses,
      recentTransactions: transactions.take(5).toList(),
    ),
  );
});

