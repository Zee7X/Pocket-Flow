// lib/features/categories_rules/domain/category.dart
enum CategoryType {
  expense,
  income,
  savings,
  debt;

  static CategoryType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'income':
        return CategoryType.income;
      case 'savings':
        return CategoryType.savings;
      case 'debt':
        return CategoryType.debt;
      case 'expense':
      default:
        return CategoryType.expense;
    }
  }

  String toDbString() => name;
}

class Category {
  final String id;
  final String userId;
  final String name;
  final CategoryType type;
  final String? icon;
  final String? color;
  final bool isDefault;
  final bool isFixed;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    this.isDefault = false,
    this.isFixed = false,
    required this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: CategoryType.fromString(json['type'] as String? ?? 'expense'),
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      isFixed: json['is_fixed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'type': type.toDbString(),
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      'is_default': isDefault,
      'is_fixed': isFixed,
    };
  }
}
