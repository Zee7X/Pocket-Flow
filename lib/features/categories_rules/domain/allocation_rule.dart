// lib/features/categories_rules/domain/allocation_rule.dart
enum AllocationType {
  fixed,
  percentage,
  capped,
  remaining,
  proportional;

  static AllocationType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'fixed':
        return AllocationType.fixed;
      case 'percentage':
        return AllocationType.percentage;
      case 'capped':
        return AllocationType.capped;
      case 'remaining':
        return AllocationType.remaining;
      case 'proportional':
        return AllocationType.proportional;
      default:
        return AllocationType.fixed;
    }
  }

  String toDbString() => name;
}

enum PercentageBase {
  remaining,
  totalIncome,
  extraIncome;

  static PercentageBase fromString(String value) {
    switch (value.toLowerCase()) {
      case 'total_income':
        return PercentageBase.totalIncome;
      case 'extra_income':
        return PercentageBase.extraIncome;
      case 'remaining_income':
      case 'remaining':
      default:
        return PercentageBase.remaining;
    }
  }

  String toDbString() {
    switch (this) {
      case PercentageBase.totalIncome:
        return 'total_income';
      case PercentageBase.extraIncome:
        return 'extra_income';
      case PercentageBase.remaining:
        return 'remaining_income';
    }
  }
}

class AllocationRule {
  final String id;
  final String userId;
  final String categoryId;
  final String name;
  final AllocationType allocationType;
  final int fixedAmount;
  final double? percentage;
  final PercentageBase percentageBase;
  final int? minAmount;
  final int? maxAmount;
  final int priority;
  final bool isRequired;
  final bool isActive;
  final String? categoryName;

  const AllocationRule({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
    required this.allocationType,
    this.fixedAmount = 0,
    this.percentage,
    this.percentageBase = PercentageBase.remaining,
    this.minAmount,
    this.maxAmount,
    this.priority = 1,
    this.isRequired = false,
    this.isActive = true,
    this.categoryName,
  });

  factory AllocationRule.fromJson(Map<String, dynamic> json) {
    return AllocationRule(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      name: json['name'] as String,
      allocationType: AllocationType.fromString(json['allocation_type'] as String? ?? 'fixed'),
      fixedAmount: (json['fixed_amount'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      percentageBase: PercentageBase.fromString(json['percentage_base'] as String? ?? 'remaining'),
      minAmount: (json['min_amount'] as num?)?.toInt(),
      maxAmount: (json['max_amount'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      isRequired: json['is_required'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      categoryName: json['pf_categories'] != null ? json['pf_categories']['name'] as String? : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'name': name,
      'allocation_type': allocationType.toDbString(),
      'fixed_amount': fixedAmount,
      if (percentage != null) 'percentage': percentage,
      'percentage_base': percentageBase.toDbString(),
      if (minAmount != null) 'min_amount': minAmount,
      if (maxAmount != null) 'max_amount': maxAmount,
      'priority': priority,
      'is_required': isRequired,
      'is_active': isActive,
    };
  }
}
