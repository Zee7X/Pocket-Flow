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
        .order('priority', ascending: true);
    final list =
        (res as List).map((json) => AllocationRule.fromJson(json)).toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    return list;
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
    // If target priority is already occupied, shift existing rules >= priority up by 1
    final conflictingRules = await _client
        .from('pf_allocation_rules')
        .select('id, priority')
        .eq('user_id', _userId)
        .gte('priority', priority)
        .order('priority', ascending: false);

    if ((conflictingRules as List).isNotEmpty) {
      for (final rule in conflictingRules) {
        final currentP = (rule['priority'] as num).toInt();
        await _client
            .from('pf_allocation_rules')
            .update({'priority': currentP + 1})
            .eq('id', rule['id'])
            .eq('user_id', _userId);
      }
    }

    final map = <String, dynamic>{
      'user_id': _userId,
      'category_id': categoryId,
      'name': name.trim(),
      'allocation_type': allocationType.toDbString(),
      'fixed_amount': fixedAmount,
      'percentage_base': percentageBase.toDbString(),
      'min_amount': minAmount ?? 0,
      'priority': priority,
      'is_required': isRequired,
      'is_active': true,
    };
    if (percentage != null) map['percentage'] = percentage;
    if (maxAmount != null) map['max_amount'] = maxAmount;

    final res = await _client
        .from('pf_allocation_rules')
        .insert(map)
        .select('*, pf_categories(name)')
        .single();
    return AllocationRule.fromJson(res);
  }

  /// Update existing allocation rule with smart priority auto-swap
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
    // 1. Check existing rule's current priority
    final existingRuleRes = await _client
        .from('pf_allocation_rules')
        .select('id, priority')
        .eq('id', id)
        .eq('user_id', _userId)
        .maybeSingle();

    if (existingRuleRes != null) {
      final oldPriority = (existingRuleRes['priority'] as num).toInt();
      if (oldPriority != priority) {
        // Find any other rule that currently has the target new priority
        final conflictingRules = await _client
            .from('pf_allocation_rules')
            .select('id')
            .eq('user_id', _userId)
            .eq('priority', priority)
            .neq('id', id);

        // Swap the conflicting rule's priority with this rule's old priority
        if ((conflictingRules as List).isNotEmpty) {
          for (final conflict in conflictingRules) {
            await _client
                .from('pf_allocation_rules')
                .update({'priority': oldPriority})
                .eq('id', conflict['id'])
                .eq('user_id', _userId);
          }
        }
      }
    }

    final map = <String, dynamic>{
      'category_id': categoryId,
      'name': name.trim(),
      'allocation_type': allocationType.toDbString(),
      'fixed_amount': fixedAmount,
      'percentage': percentage,
      'percentage_base': percentageBase.toDbString(),
      'min_amount': minAmount ?? 0,
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
