// lib/features/reports/presentation/monthly_reports_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../domain/monthly_report.dart';
import 'providers/reports_provider.dart';

class MonthlyReportsPage extends ConsumerStatefulWidget {
  const MonthlyReportsPage({super.key});

  @override
  ConsumerState<MonthlyReportsPage> createState() => _MonthlyReportsPageState();
}

class _MonthlyReportsPageState extends ConsumerState<MonthlyReportsPage> {
  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedPeriodProvider);
    final reportAsync = ref.watch(monthlyReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Laporan Keuangan',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Pilih Periode',
            onPressed: () => _openPeriodDialog(context, period),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 800,
            padding: const EdgeInsets.all(16),
            child: reportAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (report) {
                final periodLabel =
                    '${_monthNames[report.month - 1]} ${report.year}';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Hero Net Cash Flow Card ──────────────────────────
                    _buildCashFlowCard(report, periodLabel),

                    const SizedBox(height: 16),

                    // ── 2. Metric Grid: 4 Core Health Indicators ────────────
                    _buildMetricGrid(report),

                    const SizedBox(height: 24),

                    // ── 3. Analytic Donut Ring Chart (Matching Reference Image)
                    _buildAnalyticDonutCard(report),

                    const SizedBox(height: 24),

                    // ── 4. Category Breakdown Progress List ─────────────────
                    _buildCategoryBreakdown(report),

                    const SizedBox(height: 28),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. Hero Net Cash Flow Card ───────────────────────────────────────────
  Widget _buildCashFlowCard(MonthlyReport report, String periodLabel) {
    final isPositive = report.netCashFlow >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Arus Kas Bersih (Net Cash Flow)',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  isPositive ? 'Surplus 📈' : 'Defisit 📉',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.netCashFlow.toRupiah,
            style: AppTheme.monoCurrency(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Savings Rate',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                ': ${report.savingsRate.toStringAsFixed(1)}% dari total penghasilan',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 2. Metric Grid ───────────────────────────────────────────────────────
  Widget _buildMetricGrid(MonthlyReport report) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.payments_outlined,
                label: 'Gaji Masuk',
                value: report.totalIncome.toRupiah,
                color: AppTheme.success,
                bgColor: AppTheme.pastelGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.shopping_bag_outlined,
                label: 'Pengeluaran',
                value: report.totalExpense.toRupiah,
                color: AppTheme.danger,
                bgColor: AppTheme.pastelRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                icon: Icons.savings_outlined,
                label: 'Disimpan (Tabungan)',
                value: report.totalSavings.toRupiah,
                color: AppTheme.primary,
                bgColor: AppTheme.pastelBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                icon: Icons.credit_score_outlined,
                label: 'Bayar Utang',
                value: report.totalDebtPayment.toRupiah,
                color: AppTheme.warning,
                bgColor: AppTheme.pastelYellow,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return CloudPulseCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textDarkSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTheme.monoCurrency(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3. Analytic Donut Ring Chart (Matching Reference Image) ──────────────
  // ─── 3. Analytic Donut Ring Chart with Category Legend ─────────────────────
  Widget _buildAnalyticDonutCard(MonthlyReport report) {
    final activeCategories =
        report.categoryBreakdown.where((c) => c.spentAmount > 0).toList();
    final hasSpending = activeCategories.isNotEmpty && report.totalExpense > 0;

    return CloudPulseCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Analisis Pengeluaran',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textDarkPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasSpending) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '${activeCategories.length} Kategori Aktif',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Donut Chart
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: _DonutChartPainter(categories: activeCategories),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Total Belanja',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.textDarkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.totalExpense.toRupiahCompact,
                        style: AppTheme.monoCurrency(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: hasSpending ? AppTheme.danger : AppTheme.textDarkPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Percentage Breakdown Legend List
          if (hasSpending) ...[
            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderLightSubtle),
            const SizedBox(height: 12),
            Text(
              'Porsi Pengeluaran Bulan Ini:',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeCategories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final cat = activeCategories[i];
                final color = _chartPalette[i % _chartPalette.length];
                final sharePct = report.totalExpense > 0
                    ? ((cat.spentAmount / report.totalExpense) * 100).toStringAsFixed(1)
                    : '0';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLightAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(color: AppTheme.borderLightSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.categoryName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$sharePct%',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.spentAmount.toRupiah,
                        style: AppTheme.monoCurrency(
                          fontSize: 12,
                          color: AppTheme.danger,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Belum ada transaksi pengeluaran di bulan ini.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textDarkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 4. Category Breakdown List ───────────────────────────────────────────
  Widget _buildCategoryBreakdown(MonthlyReport report) {
    final categories = report.categoryBreakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rincian Pengeluaran per Kategori',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const CloudPulseCard(
            padding: EdgeInsets.all(20),
            child: EmptyStateWidget(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Belum Ada Data Pengeluaran',
              description: 'Data pengeluaran bulan ini akan muncul di sini.',
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final ratio = cat.allocatedAmount > 0
                  ? (cat.spentAmount / cat.allocatedAmount)
                  : (cat.spentAmount > 0 ? 1.0 : 0.0);
              final pct = (ratio * 100).toStringAsFixed(0);
              final isOver = cat.isOverBudget;
              final sharePct = report.totalExpense > 0 && cat.spentAmount > 0
                  ? ' • ${((cat.spentAmount / report.totalExpense) * 100).toStringAsFixed(1)}% total'
                  : '';

              return CloudPulseCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.categoryName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textDarkPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: cat.spentAmount.toRupiah,
                                  style: AppTheme.monoCurrency(
                                    fontSize: 11.5,
                                    color: cat.spentAmount > 0
                                        ? AppTheme.danger
                                        : AppTheme.textDarkPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / ${cat.allocatedAmount.toRupiah}',
                                  style: AppTheme.monoCurrency(
                                    fontSize: 11.5,
                                    color: AppTheme.textDarkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppTheme.surfaceLightAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isOver ? AppTheme.danger : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$pct% terpakai$sharePct',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isOver
                                  ? AppTheme.danger
                                  : AppTheme.textDarkSecondary,
                              fontWeight: isOver
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOver
                              ? 'Over Budget!'
                              : 'Sisa: ${cat.remaining.toRupiah}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: isOver
                                ? AppTheme.danger
                                : AppTheme.success,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _openPeriodDialog(
      BuildContext context, ({int month, int year}) current) async {
    int m = current.month;
    int y = current.year;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text(
          'Pilih Periode Laporan',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: m,
                items: List.generate(12, (i) => i + 1).map((idx) {
                  return DropdownMenuItem(
                    value: idx,
                    child: Text(
                      _monthNames[idx - 1],
                      style: GoogleFonts.dmSans(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => m = val ?? m,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: y,
                items: [2024, 2025, 2026, 2027].map((yr) {
                  return DropdownMenuItem(
                    value: yr,
                    child: Text(
                      '$yr',
                      style: GoogleFonts.dmSans(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => y = val ?? y,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ref.read(selectedPeriodProvider.notifier).state =
                  (month: m, year: y);
              Navigator.pop(ctx);
            },
            child: const Text('Tampilkan'),
          ),
        ],
      ),
    );
  }
}

const List<Color> _chartPalette = [
  Color(0xFF2563EB), // Royal Blue
  Color(0xFF0EA5E9), // Cyan
  Color(0xFF10B981), // Emerald
  Color(0xFFF59E0B), // Amber
  Color(0xFF8B5CF6), // Violet
  Color(0xFFEC4899), // Pink
  Color(0xFF06B6D4), // Teal
  Color(0xFFF97316), // Orange
];

class _DonutChartPainter extends CustomPainter {
  final List<CategorySpendingSummary> categories;

  _DonutChartPainter({required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 18.0;

    final paintBg = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paintBg);

    final total =
        categories.fold<int>(0, (sum, c) => sum + c.spentAmount);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < categories.length; i++) {
      final sweepAngle = (categories[i].spentAmount / total) * 2 * math.pi;
      final paintSlice = Paint()
        ..color = _chartPalette[i % _chartPalette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle > 0.05 ? sweepAngle - 0.04 : sweepAngle,
        false,
        paintSlice,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
