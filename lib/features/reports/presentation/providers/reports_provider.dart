// lib/features/reports/presentation/providers/reports_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../data/report_repository.dart';
import '../../domain/monthly_report.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepository(ref.watch(supabaseClientProvider));
});

final reportSelectedPeriodProvider =
    StateProvider<({int month, int year})>((ref) {
  return ref.watch(selectedPeriodProvider);
});

final monthlyReportProvider = FutureProvider<MonthlyReport>((ref) async {
  final period = ref.watch(reportSelectedPeriodProvider);
  if (ref.watch(currentUserIdProvider) == null) {
    return MonthlyReport(
      month: period.month,
      year: period.year,
      totalIncome: 0,
      totalExpense: 0,
      totalSavings: 0,
      totalDebtPayment: 0,
      netCashFlow: 0,
      savingsRate: 0,
      categoryBreakdown: const [],
      rawBudgets: const [],
    );
  }
  return ref.watch(reportRepositoryProvider).getMonthlyReport(
        month: period.month,
        year: period.year,
      );
});
