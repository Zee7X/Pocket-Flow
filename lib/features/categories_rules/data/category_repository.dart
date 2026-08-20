// lib/features/categories_rules/data/category_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/category.dart';
import '../domain/category_template.dart';

class CategoryRepository {
  final SupabaseClient _client;

  CategoryRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch all categories for current user
  Future<List<Category>> getCategories() async {
    final res = await _client
        .from('pf_categories')
        .select()
        .eq('user_id', _userId)
        .order('name');
    return (res as List).map((json) => Category.fromJson(json)).toList();
  }

  /// Create a new category
  Future<Category> createCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final map = <String, dynamic>{
      'user_id': _userId,
      'name': name.trim(),
      'type': type.toDbString(),
    };
    if (icon != null) map['icon'] = icon;
    if (color != null) map['color'] = color;

    final res = await _client
        .from('pf_categories')
        .insert(map)
        .select()
        .single();
    return Category.fromJson(res);
  }

  /// Delete category
  Future<void> deleteCategory(String categoryId) async {
    await _client
        .from('pf_categories')
        .delete()
        .eq('id', categoryId)
        .eq('user_id', _userId);
  }

  /// Fetch available onboarding templates from system
  Future<List<TemplateGroup>> getCategoryTemplates() async {
    final res = await _client
        .from('pf_category_templates')
        .select()
        .order('sort_order');
    final items =
        (res as List).map((json) => CategoryTemplateItem.fromJson(json)).toList();

    final Map<String, List<CategoryTemplateItem>> grouped = {};
    final Map<String, String> names = {};

    for (final item in items) {
      grouped.putIfAbsent(item.templateKey, () => []).add(item);
      names[item.templateKey] = item.templateName;
    }

    return grouped.entries.map((e) {
      return TemplateGroup(
        key: e.key,
        name: names[e.key] ?? e.key,
        items: e.value,
      );
    }).toList();
  }

  /// Apply an onboarding template: creates categories and default allocation rules
  Future<void> applyTemplate(String templateKey) async {
    final res = await _client
        .from('pf_category_templates')
        .select()
        .eq('template_key', templateKey)
        .order('sort_order');
    final items =
        (res as List).map((json) => CategoryTemplateItem.fromJson(json)).toList();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      // 1. Create category
      final catRes = await _client
          .from('pf_categories')
          .insert({
            'user_id': _userId,
            'name': item.categoryName,
            'type': item.categoryType,
            'is_default': true,
          })
          .select()
          .single();
      final catId = catRes['id'] as String;

      // 2. Create allocation rule
      final ruleMap = <String, dynamic>{
        'user_id': _userId,
        'category_id': catId,
        'name': item.categoryName,
        'allocation_type': item.defaultAllocationType,
        'fixed_amount': item.defaultFixedAmount,
        'priority': i + 1,
        'is_active': true,
      };
      if (item.defaultPercentage != null) {
        ruleMap['percentage'] = item.defaultPercentage;
      }
      await _client.from('pf_allocation_rules').insert(ruleMap);
    }
  }
}
