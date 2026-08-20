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
    return ref.watch(categoryRepositoryProvider).getCategories();
  }

  Future<void> addCategory({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) async {
    final newCat = await ref.read(categoryRepositoryProvider).createCategory(
          name: name,
          type: type,
          icon: icon,
          color: color,
        );
    state = AsyncValue.data([...(state.value ?? []), newCat]);
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
    final newRule =
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
    state = AsyncValue.data([...(state.value ?? []), newRule]);
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
    final updatedRule =
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
    state = AsyncValue.data(
      (state.value ?? []).map((r) => r.id == id ? updatedRule : r).toList(),
    );
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
