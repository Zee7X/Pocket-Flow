// lib/features/insights/presentation/providers/insights_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../domain/insight_engine.dart';
import 'history_provider.dart';

final insightsProvider = Provider<List<Insight>>((ref) {
  final history = ref.watch(recentHistoryProvider).value ?? const [];
  final period = ref.watch(selectedPeriodProvider);
  final budgets = ref.watch(monthlyBudgetsProvider).value ?? const [];
  final living = budgets
      .where((b) => !b.isSavings && !b.isDebt)
      .fold<int>(0, (s, b) => s + b.allocatedAmount);
  return const InsightEngine().build(
    history: history,
    month: period.month,
    year: period.year,
    monthlyBudget: living > 0 ? living : null,
  );
});
