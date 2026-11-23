// lib/features/insights/presentation/widgets/insights_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/insight_engine.dart';
import '../providers/insights_provider.dart';

class InsightsCard extends ConsumerWidget {
  /// Batasi jumlah insight (dashboard: 3, laporan: semua).
  final int? limit;
  final String title;

  const InsightsCard({super.key, this.limit, this.title = 'Insight bulan ini'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(insightsProvider);
    if (all.isEmpty) return const SizedBox.shrink();
    final items = limit == null ? all : all.take(limit!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 60),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(
                        _icon(it.kind),
                        color: _color(it.tone),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              style: Ui.body(
                                size: 14,
                                color: AppTheme.textDarkPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(it.body, style: Ui.body(size: 12.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static IconData _icon(InsightKind k) => switch (k) {
    InsightKind.trend => Icons.show_chart_rounded,
    InsightKind.category => Icons.category_outlined,
    InsightKind.merchant => Icons.storefront_outlined,
    InsightKind.weekday => Icons.calendar_view_week_outlined,
    InsightKind.projection => Icons.flag_outlined,
    InsightKind.savings => Icons.savings_outlined,
  };

  static Color _color(InsightTone t) => switch (t) {
    InsightTone.good => const Color(0xFF059669),
    InsightTone.bad => AppTheme.danger,
    InsightTone.neutral => AppTheme.primary,
  };
}
