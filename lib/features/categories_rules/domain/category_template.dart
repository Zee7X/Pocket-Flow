// lib/features/categories_rules/domain/category_template.dart
class CategoryTemplateItem {
  final String id;
  final String templateKey;
  final String templateName;
  final String categoryName;
  final String categoryType;
  final String defaultAllocationType;
  final int defaultFixedAmount;
  final double? defaultPercentage;
  final int sortOrder;

  const CategoryTemplateItem({
    required this.id,
    required this.templateKey,
    required this.templateName,
    required this.categoryName,
    required this.categoryType,
    required this.defaultAllocationType,
    this.defaultFixedAmount = 0,
    this.defaultPercentage,
    required this.sortOrder,
  });

  factory CategoryTemplateItem.fromJson(Map<String, dynamic> json) {
    return CategoryTemplateItem(
      id: json['id'] as String,
      templateKey: json['template_key'] as String,
      templateName: json['template_name'] as String,
      categoryName: json['category_name'] as String,
      categoryType: json['category_type'] as String,
      defaultAllocationType: json['default_allocation_type'] as String,
      defaultFixedAmount: (json['default_fixed_amount'] as num?)?.toInt() ?? 0,
      defaultPercentage: (json['default_percentage'] as num?)?.toDouble(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class TemplateGroup {
  final String key;
  final String name;
  final List<CategoryTemplateItem> items;

  const TemplateGroup({
    required this.key,
    required this.name,
    required this.items,
  });
}
