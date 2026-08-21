// lib/features/salary_allocation/presentation/providers/salary_allocation_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/salary_repository.dart';
import '../../domain/monthly_budget.dart';
import '../../domain/salary_allocation_result.dart';
import '../../domain/salary_entry.dart';

final salaryRepositoryProvider = Provider<SalaryRepository>((ref) {
  return SalaryRepository(ref.watch(supabaseClientProvider));
});

// Selected period state (defaults to current month and year)
final selectedPeriodProvider = StateProvider<({int month, int year})>((ref) {
  final now = DateTime.now();
  return (month: now.month, year: now.year);
});

// Monthly budgets for selected period
final monthlyBudgetsProvider =
    FutureProvider<List<MonthlyBudget>>((ref) async {
  final period = ref.watch(selectedPeriodProvider);
  return ref.watch(salaryRepositoryProvider).getMonthlyBudgets(
        periodMonth: period.month,
        periodYear: period.year,
      );
});

// Salary history
final salaryHistoryProvider =
    FutureProvider<List<SalaryEntry>>((ref) async {
  return ref.watch(salaryRepositoryProvider).getSalaryHistory();
});

// Allocation engine action notifier
final salaryAllocationActionProvider =
    StateNotifierProvider<SalaryAllocationActionNotifier, AsyncValue<SalaryAllocationResult?>>(
  (ref) => SalaryAllocationActionNotifier(ref.watch(salaryRepositoryProvider), ref),
);

class SalaryAllocationActionNotifier
    extends StateNotifier<AsyncValue<SalaryAllocationResult?>> {
  final SalaryRepository _repository;
  final Ref _ref;

  SalaryAllocationActionNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(null));

  /// Live read-only preview
  Future<SalaryAllocationResult?> preview({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.previewAllocation(
        salaryAmount: salaryAmount,
        salaryDate: salaryDate,
        periodMonth: periodMonth,
        periodYear: periodYear,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Execute allocation into DB
  Future<SalaryAllocationResult?> execute({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _repository.allocateSalary(
        salaryAmount: salaryAmount,
        salaryDate: salaryDate,
        periodMonth: periodMonth,
        periodYear: periodYear,
      );
      state = AsyncValue.data(result);
      // Invalidate relevant providers
      _ref.invalidate(monthlyBudgetsProvider);
      _ref.invalidate(salaryHistoryProvider);
      _ref.invalidate(transactionsProvider);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}
