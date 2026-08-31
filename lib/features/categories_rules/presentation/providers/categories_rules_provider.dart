// lib/features/categories_rules/presentation/providers/categories_rules_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/category_repository.dart';
import '../../data/allocation_rule_repository.dart';
import '../../domain/category.dart';
import '../../domain/allocation_rule.dart';
import '../../domain/category_template.dart';

// ─── Repositories ────────────────────────────────────────────────────────────
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(supabaseClientProvider));
});

final allocationRuleRepositoryProvider =
    Provider<AllocationRuleRepository>((ref) {
  return AllocationRuleRepository(ref.watch(supabaseClientProvider));
});

// ─── Categories Provider ─────────────────────────────────────────────────────
final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.watch(categoryRepositoryProvider).getCategories();
  }

  Future<Category> addCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    bool isFixed = false,
  }) async {
    final newCat = await ref.read(categoryRepositoryProvider).createCategory(
          name: name,
          type: type,
          icon: icon,
          color: color,
          isFixed: isFixed,
        );
    state = AsyncValue.data([...(state.value ?? []), newCat]);
    return newCat;
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
    bool isFixed = false,
  }) async {
    final updated = await ref.read(categoryRepositoryProvider).updateCategory(
          id: id,
          name: name,
          type: type,
          icon: icon,
          color: color,
          isFixed: isFixed,
        );
    state = AsyncValue.data(
      (state.value ?? []).map((c) => c.id == id ? updated : c).toList(),
    );
  }

  Future<void> toggleCategoryIsFixed(String categoryId, bool isFixed) async {
    await ref.read(categoryRepositoryProvider).updateCategoryIsFixed(
          categoryId: categoryId,
          isFixed: isFixed,
        );
    state = AsyncValue.data(
      (state.value ?? []).map((c) {
        if (c.id == categoryId) {
          return Category(
            id: c.id,
            userId: c.userId,
            name: c.name,
            type: c.type,
            icon: c.icon,
            color: c.color,
            isDefault: c.isDefault,
            isFixed: isFixed,
            createdAt: c.createdAt,
          );
        }
        return c;
      }).toList(),
    );
  }


  Future<void> deleteCategory(String categoryId) async {
    await ref.read(categoryRepositoryProvider).deleteCategory(categoryId);
    state = AsyncValue.data(
      (state.value ?? []).where((c) => c.id != categoryId).toList(),
    );
  }

  Future<void> applyTemplate(String templateKey) async {
    await ref.read(categoryRepositoryProvider).applyTemplate(templateKey);
    final freshCats =
        await ref.read(categoryRepositoryProvider).getCategories();
    state = AsyncValue.data(freshCats);
    ref.invalidate(allocationRulesProvider);
  }
}

// ─── Templates Provider ──────────────────────────────────────────────────────
final categoryTemplatesProvider =
    FutureProvider<List<TemplateGroup>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getCategoryTemplates();
});

// ─── Allocation Rules Provider ───────────────────────────────────────────────
final allocationRulesProvider =
    AsyncNotifierProvider<AllocationRulesNotifier, List<AllocationRule>>(
  AllocationRulesNotifier.new,
);

class AllocationRulesNotifier extends AsyncNotifier<List<AllocationRule>> {
  @override
  Future<List<AllocationRule>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    return ref.watch(allocationRuleRepositoryProvider).getAllocationRules();
  }

  Future<void> addRule({
    required String categoryId,
    required String name,
    required AllocationType allocationType,
    int fixedAmount = 0,
    double? percentage,
    PercentageBase percentageBase = PercentageBase.remaining,
    int? minAmount,
    int? maxAmount,
    int priority = 1,
    bool isRequired = false,
  }) async {
    await ref.read(allocationRuleRepositoryProvider).createAllocationRule(
          categoryId: categoryId,
          name: name,
          allocationType: allocationType,
          fixedAmount: fixedAmount,
          percentage: percentage,
          percentageBase: percentageBase,
          minAmount: minAmount,
          maxAmount: maxAmount,
          priority: priority,
          isRequired: isRequired,
        );
    final freshRules =
        await ref.read(allocationRuleRepositoryProvider).getAllocationRules();
    state = AsyncValue.data(freshRules);
  }

  Future<void> updateRule({
    required String id,
    required String categoryId,
    required String name,
    required AllocationType allocationType,
    int fixedAmount = 0,
    double? percentage,
    PercentageBase percentageBase = PercentageBase.remaining,
    int? minAmount,
    int? maxAmount,
    int priority = 1,
    bool isRequired = false,
  }) async {
    await ref.read(allocationRuleRepositoryProvider).updateAllocationRule(
          id: id,
          categoryId: categoryId,
          name: name,
          allocationType: allocationType,
          fixedAmount: fixedAmount,
          percentage: percentage,
          percentageBase: percentageBase,
          minAmount: minAmount,
          maxAmount: maxAmount,
          priority: priority,
          isRequired: isRequired,
        );
    final freshRules =
        await ref.read(allocationRuleRepositoryProvider).getAllocationRules();
    state = AsyncValue.data(freshRules);
  }

  Future<void> toggleActive(String ruleId, bool isActive) async {
    await ref
        .read(allocationRuleRepositoryProvider)
        .toggleActive(ruleId, isActive);
    state = AsyncValue.data(
      (state.value ?? []).map((r) {
        if (r.id == ruleId) {
          return AllocationRule(
            id: r.id,
            userId: r.userId,
            categoryId: r.categoryId,
            name: r.name,
            allocationType: r.allocationType,
            fixedAmount: r.fixedAmount,
            percentage: r.percentage,
            percentageBase: r.percentageBase,
            minAmount: r.minAmount,
            maxAmount: r.maxAmount,
            priority: r.priority,
            isRequired: r.isRequired,
            isActive: isActive,
            categoryName: r.categoryName,
          );
        }
        return r;
      }).toList(),
    );
  }

  Future<void> deleteRule(String ruleId) async {
    await ref.read(allocationRuleRepositoryProvider).deleteAllocationRule(ruleId);
    state = AsyncValue.data(
      (state.value ?? []).where((r) => r.id != ruleId).toList(),
    );
  }
}
