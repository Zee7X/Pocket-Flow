// lib/features/salary_allocation/domain/salary_allocation_result.dart
class RuleAllocationItem {
  final String ruleId;
  final String ruleName;
  final String categoryId;
  final String allocationType;
  final int allocatedAmount;

  const RuleAllocationItem({
    required this.ruleId,
    required this.ruleName,
    required this.categoryId,
    required this.allocationType,
    required this.allocatedAmount,
  });

  factory RuleAllocationItem.fromJson(Map<String, dynamic> json) {
    return RuleAllocationItem(
      ruleId: json['rule_id'] as String,
      ruleName: json['rule_name'] as String,
      categoryId: json['category_id'] as String,
      allocationType: json['allocation_type'] as String,
      allocatedAmount: (json['allocated_amount'] as num).toInt(),
    );
  }
}

class AllocationWarning {
  final String code;
  final String message;
  final String? ruleName;
  final int? shortfall;

  const AllocationWarning({
    required this.code,
    required this.message,
    this.ruleName,
    this.shortfall,
  });

  factory AllocationWarning.fromJson(Map<String, dynamic> json) {
    return AllocationWarning(
      code: json['code'] as String? ?? 'WARNING',
      message: json['message'] as String? ?? '',
      ruleName: json['rule_name'] as String?,
      shortfall: (json['shortfall'] as num?)?.toInt(),
    );
  }
}

class SalaryAllocationResult {
  final bool success;
  final bool isPreview;
  final String? salaryEntryId;
  final int salaryAmount;
  final int totalAllocated;
  final int remaining;
  final int extraIncome;
  final int periodMonth;
  final int periodYear;
  final List<RuleAllocationItem> allocations;
  final List<AllocationWarning> warnings;

  const SalaryAllocationResult({
    required this.success,
    this.isPreview = false,
    this.salaryEntryId,
    required this.salaryAmount,
    required this.totalAllocated,
    required this.remaining,
    this.extraIncome = 0,
    required this.periodMonth,
    required this.periodYear,
    required this.allocations,
    required this.warnings,
  });

  factory SalaryAllocationResult.fromJson(Map<String, dynamic> json) {
    final allocList = (json['allocations'] as List<dynamic>?)
            ?.map((e) => RuleAllocationItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final warnList = (json['warnings'] as List<dynamic>?)
            ?.map((e) => AllocationWarning.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return SalaryAllocationResult(
      success: json['success'] as bool? ?? false,
      isPreview: json['is_preview'] as bool? ?? false,
      salaryEntryId: json['salary_entry_id'] as String?,
      salaryAmount: (json['salary_amount'] as num).toInt(),
      totalAllocated: (json['total_allocated'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      extraIncome: (json['extra_income'] as num?)?.toInt() ?? 0,
      periodMonth: (json['period_month'] as num).toInt(),
      periodYear: (json['period_year'] as num).toInt(),
      allocations: allocList,
      warnings: warnList,
    );
  }
}
