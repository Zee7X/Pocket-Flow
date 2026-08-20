// lib/features/reports/data/report_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../salary_allocation/domain/monthly_budget.dart';
import '../domain/monthly_report.dart';

class ReportRepository {
  final SupabaseClient _client;

  ReportRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch comprehensive financial report for a specific month/year
  Future<MonthlyReport> getMonthlyReport({
    required int month,
    required int year,
  }) async {
    final startStr = '$year-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endStr = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

    // 1. Fetch Salary Entries
    final salaryRes = await _client
        .from('pf_salary_entries')
        .select('amount')
        .eq('user_id', _userId)
        .eq('period_month', month)
        .eq('period_year', year);
    int totalSalary = 0;
    for (final s in (salaryRes as List)) {
      totalSalary += (s['amount'] as num).toInt();
    }

    // 2. Fetch Transactions (Expense & Income)
    final txRes = await _client
        .from('pf_transactions')
        .select('type, amount, category_id, pf_categories(name, type)')
        .eq('user_id', _userId)
        .gte('transaction_date', startStr)
        .lt('transaction_date', endStr);

    int totalExpense = 0;
    int extraIncome = 0;
    final Map<String, int> spentPerCategory = {};

    for (final t in (txRes as List)) {
      final type = t['type'] as String;
      final amount = (t['amount'] as num).toInt();
      final cat = t['pf_categories'] as Map<String, dynamic>?;
      final catName = cat != null ? (cat['name'] as String? ?? 'Lainnya') : 'Lainnya';

      if (type == 'expense') {
        totalExpense += amount;
        spentPerCategory[catName] = (spentPerCategory[catName] ?? 0) + amount;
      } else if (type == 'income') {
        extraIncome += amount;
      }
    }

    final totalIncome = totalSalary + extraIncome;

    // 3. Fetch Monthly Budgets
    final budgetRes = await _client
        .from('pf_monthly_budgets')
        .select('*, pf_categories(name)')
        .eq('user_id', _userId)
        .eq('period_month', month)
        .eq('period_year', year);
    final budgets =
        (budgetRes as List).map((json) => MonthlyBudget.fromJson(json)).toList();

    // 4. Fetch Debt Payments
    final debtPaymentRes = await _client
        .from('pf_debt_payments')
        .select('amount')
        .eq('user_id', _userId)
        .gte('payment_date', startStr)
        .lt('payment_date', endStr);
    int totalDebtPayment = 0;
    for (final d in (debtPaymentRes as List)) {
      totalDebtPayment += (d['amount'] as num).toInt();
    }

    // 5. Fetch Savings Deposits
    final savingsRes = await _client
        .from('pf_savings_transactions')
        .select('amount, type')
        .eq('user_id', _userId)
        .gte('created_at', startStr)
        .lt('created_at', endStr);
    int totalSavings = 0;
    for (final s in (savingsRes as List)) {
      final stype = s['type'] as String;
      final amount = (s['amount'] as num).toInt();
      if (stype == 'deposit') {
        totalSavings += amount;
      }
    }

    // 6. Calculate Net Cash Flow & Savings Rate
    final netCashFlow = totalIncome - totalExpense - totalDebtPayment;
    final savingsRate = totalIncome > 0 ? (totalSavings / totalIncome) * 100 : 0.0;

    // 7. Build Category Breakdown
    final List<CategorySpendingSummary> breakdown = [];
    for (final b in budgets) {
      final name = b.categoryName ?? 'Kategori';
      final spent = b.spentAmount;
      final pct = totalExpense > 0 ? (spent / totalExpense) : 0.0;
      breakdown.add(
        CategorySpendingSummary(
          categoryName: name,
          allocatedAmount: b.allocatedAmount,
          spentAmount: spent,
          percentageOfTotalSpent: pct,
        ),
      );
      spentPerCategory.remove(name);
    }

    // Add any non-budgeted expenses
    spentPerCategory.forEach((name, spent) {
      final pct = totalExpense > 0 ? (spent / totalExpense) : 0.0;
      breakdown.add(
        CategorySpendingSummary(
          categoryName: name,
          allocatedAmount: 0,
          spentAmount: spent,
          percentageOfTotalSpent: pct,
        ),
      );
    });

    return MonthlyReport(
      month: month,
      year: year,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalSavings: totalSavings,
      totalDebtPayment: totalDebtPayment,
      netCashFlow: netCashFlow,
      savingsRate: savingsRate,
      categoryBreakdown: breakdown,
      rawBudgets: budgets,
    );
  }
}
