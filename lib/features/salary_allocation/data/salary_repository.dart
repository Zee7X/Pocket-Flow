// lib/features/salary_allocation/data/salary_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/monthly_budget.dart';
import '../domain/salary_allocation_result.dart';
import '../domain/salary_entry.dart';

class SalaryRepository {
  final SupabaseClient _client;

  SalaryRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Call read-only preview RPC: calculates allocation breakdown without saving
  Future<SalaryAllocationResult> previewAllocation({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    final res = await _client.rpc('pf_preview_allocation', params: {
      'p_salary_amount': salaryAmount,
      'p_salary_date': salaryDate.toIso8601String().split('T').first,
      'p_period_month': periodMonth,
      'p_period_year': periodYear,
    });
    return SalaryAllocationResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Call atomic allocation RPC: creates salary entry + generates monthly budgets
  Future<SalaryAllocationResult> allocateSalary({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    final res = await _client.rpc('pf_allocate_salary', params: {
      'p_salary_amount': salaryAmount,
      'p_salary_date': salaryDate.toIso8601String().split('T').first,
      'p_period_month': periodMonth,
      'p_period_year': periodYear,
    });
    return SalaryAllocationResult.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Fetch monthly budgets for a specific period
  Future<List<MonthlyBudget>> getMonthlyBudgets({
    required int periodMonth,
    required int periodYear,
  }) async {
    final res = await _client
        .from('pf_monthly_budgets')
        .select('*, pf_categories(name, type, icon, color, is_fixed)')
        .eq('user_id', _userId)
        .eq('period_month', periodMonth)
        .eq('period_year', periodYear);
    return (res as List).map((json) => MonthlyBudget.fromJson(json)).toList();
  }

  /// Fetch history of salary entries
  Future<List<SalaryEntry>> getSalaryHistory() async {
    final res = await _client
        .from('pf_salary_entries')
        .select()
        .eq('user_id', _userId)
        .order('period_year', ascending: false)
        .order('period_month', ascending: false);
    return (res as List).map((json) => SalaryEntry.fromJson(json)).toList();
  }

  /// Update single category budget allocation for a specific period
  Future<void> updateCategoryBudget({
    required String categoryId,
    required int periodMonth,
    required int periodYear,
    required int newAllocatedAmount,
  }) async {
    await _client
        .from('pf_monthly_budgets')
        .update({
          'allocated_amount': newAllocatedAmount,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _userId)
        .eq('category_id', categoryId)
        .eq('period_month', periodMonth)
        .eq('period_year', periodYear);
  }
}
