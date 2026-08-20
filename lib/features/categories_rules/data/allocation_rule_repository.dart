// lib/features/categories_rules/data/allocation_rule_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/allocation_rule.dart';

class AllocationRuleRepository {
  final SupabaseClient _client;

  AllocationRuleRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// Fetch all allocation rules for current user with category join
  Future<List<AllocationRule>> getAllocationRules() async {
    final res = await _client
        .from('pf_allocation_rules')
        .select('*, pf_categories(name)')
        .eq('user_id', _userId)
        .order('priority');
    return (res as List).map((json) => AllocationRule.fromJson(json)).toList();
  }

  /// Create a new allocation rule
  Future<AllocationRule> createAllocationRule({
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
    final map = <String, dynamic>{
      'user_id': _userId,
      'category_id': categoryId,
      'name': name.trim(),
      'allocation_type': allocationType.toDbString(),
      'fixed_amount': fixedAmount,
      'percentage_base': percentageBase.toDbString(),
      'priority': priority,
      'is_required': isRequired,
      'is_active': true,
    };
    if (percentage != null) map['percentage'] = percentage;
    if (minAmount != null) map['min_amount'] = minAmount;
    if (maxAmount != null) map['max_amount'] = maxAmount;

    final res = await _client
        .from('pf_allocation_rules')
        .insert(map)
        .select('*, pf_categories(name)')
        .single();
    return AllocationRule.fromJson(res);
  }

  /// Update existing allocation rule
  Future<AllocationRule> updateAllocationRule({
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
    final map = <String, dynamic>{
      'category_id': categoryId,
      'name': name.trim(),
      'allocation_type': allocationType.toDbString(),
      'fixed_amount': fixedAmount,
      'percentage': percentage,
      'percentage_base': percentageBase.toDbString(),
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'priority': priority,
      'is_required': isRequired,
    };

    final res = await _client
        .from('pf_allocation_rules')
        .update(map)
        .eq('id', id)
        .eq('user_id', _userId)
        .select('*, pf_categories(name)')
        .single();
    return AllocationRule.fromJson(res);
  }

  /// Toggle rule active status
  Future<void> toggleActive(String ruleId, bool isActive) async {
    await _client
        .from('pf_allocation_rules')
        .update({'is_active': isActive})
        .eq('id', ruleId)
        .eq('user_id', _userId);
  }

  /// Delete allocation rule
  Future<void> deleteAllocationRule(String ruleId) async {
    await _client
        .from('pf_allocation_rules')
        .delete()
        .eq('id', ruleId)
        .eq('user_id', _userId);
  }

  /// Update priority of rules
  Future<void> updatePriorities(List<String> ruleIds) async {
    for (int i = 0; i < ruleIds.length; i++) {
      await _client
          .from('pf_allocation_rules')
          .update({'priority': i + 1})
          .eq('id', ruleIds[i])
          .eq('user_id', _userId);
    }
  }
}
