// lib/features/salary_allocation/domain/monthly_budget.dart
class MonthlyBudget {
  final String id;
  final String userId;
  final String categoryId;
  final String? salaryEntryId;
  final String? allocationRuleId;
  final int periodMonth;
  final int periodYear;
  final int allocatedAmount;
  final int spentAmount;
  final String? categoryName;
  final String? categoryType;
  final String? categoryIcon;
  final String? categoryColor;
  final bool categoryIsFixed;

  const MonthlyBudget({
    required this.id,
    required this.userId,
    required this.categoryId,
    this.salaryEntryId,
    this.allocationRuleId,
    required this.periodMonth,
    required this.periodYear,
    required this.allocatedAmount,
    this.spentAmount = 0,
    this.categoryName,
    this.categoryType,
    this.categoryIcon,
    this.categoryColor,
    this.categoryIsFixed = false,
  });

  int get remainingAmount => allocatedAmount - spentAmount;
  double get spentPercentage =>
      allocatedAmount > 0 ? (spentAmount / allocatedAmount).clamp(0.0, 1.0) : 0.0;
  bool get isOverBudget => spentAmount > allocatedAmount;

  /// Only variable expense categories should show daily spending limit.
  /// Fixed costs (rent, utilities) are excluded.
  bool get isDailyTrackable =>
      (categoryType == 'expense') && !categoryIsFixed;

  factory MonthlyBudget.fromJson(Map<String, dynamic> json) {
    final cat = json['pf_categories'] as Map<String, dynamic>?;
    return MonthlyBudget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      salaryEntryId: json['salary_entry_id'] as String?,
      allocationRuleId: json['allocation_rule_id'] as String?,
      periodMonth: (json['period_month'] as num).toInt(),
      periodYear: (json['period_year'] as num).toInt(),
      allocatedAmount: (json['allocated_amount'] as num).toInt(),
      spentAmount: (json['spent_amount'] as num?)?.toInt() ?? 0,
      categoryName: cat?['name'] as String?,
      categoryType: cat?['type'] as String?,
      categoryIcon: cat?['icon'] as String?,
      categoryColor: cat?['color'] as String?,
      categoryIsFixed: cat?['is_fixed'] as bool? ?? false,
    );
  }
}
