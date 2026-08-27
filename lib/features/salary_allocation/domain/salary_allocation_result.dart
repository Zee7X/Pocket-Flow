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
    final ruleName = (json['rule_name'] ?? json['category_name']) as String? ?? 'Alokasi';
    final categoryId = (json['category_id'] ?? json['rule_id']) as String? ?? '';
    final ruleId = (json['rule_id'] ?? json['category_id']) as String? ?? categoryId;
    final allocType = json['allocation_type'] as String? ?? 'fixed';
    final allocAmount = (json['allocated_amount'] as num?)?.toInt() ?? 0;

    return RuleAllocationItem(
      ruleId: ruleId,
      ruleName: ruleName,
      categoryId: categoryId,
      allocationType: allocType,
      allocatedAmount: allocAmount,
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
      ruleName: (json['rule_name'] ?? json['category_name']) as String?,
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
    final rawAllocations = json['allocations'];
    final allocList = (rawAllocations is List)
        ? rawAllocations
            .map((e) => RuleAllocationItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <RuleAllocationItem>[];

    final rawWarnings = json['warnings'];
    final warnList = (rawWarnings is List)
        ? rawWarnings
            .map((e) => AllocationWarning.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <AllocationWarning>[];

    final totalAllocated = (json['total_allocated'] as num?)?.toInt() ?? 0;
    final rawRemaining = json['remaining'] ?? json['remaining_income'];
    final remaining = (rawRemaining as num?)?.toInt() ?? 0;
    final salaryAmount = (json['salary_amount'] as num?)?.toInt() ?? 0;

    return SalaryAllocationResult(
      success: json['success'] as bool? ?? true,
      isPreview: json['is_preview'] as bool? ?? false,
      salaryEntryId: json['salary_entry_id'] as String?,
      salaryAmount: salaryAmount,
      totalAllocated: totalAllocated,
      remaining: remaining,
      extraIncome: (json['extra_income'] as num?)?.toInt() ?? 0,
      periodMonth: (json['period_month'] as num?)?.toInt() ?? 1,
      periodYear: (json['period_year'] as num?)?.toInt() ?? DateTime.now().year,
      allocations: allocList,
      warnings: warnList,
    );
  }
}
