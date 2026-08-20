// lib/features/reports/domain/monthly_report.dart
import '../../salary_allocation/domain/monthly_budget.dart';

class CategorySpendingSummary {
  final String categoryName;
  final String? categoryType;
  final int allocatedAmount;
  final int spentAmount;
  final double percentageOfTotalSpent;

  const CategorySpendingSummary({
    required this.categoryName,
    this.categoryType,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.percentageOfTotalSpent,
  });

  bool get isOverBudget => spentAmount > allocatedAmount && allocatedAmount > 0;
  int get remaining => (allocatedAmount - spentAmount) > 0 ? (allocatedAmount - spentAmount) : 0;
}

class MonthlyReport {
  final int month;
  final int year;
  final int totalIncome;
  final int totalExpense;
  final int totalSavings;
  final int totalDebtPayment;
  final int netCashFlow;
  final double savingsRate;
  final List<CategorySpendingSummary> categoryBreakdown;
  final List<MonthlyBudget> rawBudgets;

  const MonthlyReport({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.totalDebtPayment,
    required this.netCashFlow,
    required this.savingsRate,
    required this.categoryBreakdown,
    required this.rawBudgets,
  });

  String get monthName {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[month - 1];
  }
}
