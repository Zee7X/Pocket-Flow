// lib/features/salary_allocation/presentation/widgets/salary_history_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../domain/monthly_budget.dart';
import '../../domain/salary_entry.dart';
import '../providers/salary_allocation_provider.dart';

class SalaryHistoryDetailSheet extends ConsumerWidget {
  final SalaryEntry entry;
  final VoidCallback onEditForm;

  const SalaryHistoryDetailSheet({
    super.key,
    required this.entry,
    required this.onEditForm,
  });

  static Future<void> show(
    BuildContext context, {
    required SalaryEntry entry,
    required VoidCallback onEditForm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: false,
      barrierColor: const Color(0x73000000),
      backgroundColor: Colors.transparent,
      builder: (_) => SalaryHistoryDetailSheet(
        entry: entry,
        onEditForm: onEditForm,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodStr = DateFormat('MMMM yyyy')
        .format(DateTime(entry.periodYear, entry.periodMonth));
    final salaryRepo = ref.watch(salaryRepositoryProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            periodStr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDarkPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Teralokasi',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Diterima: ${DateFormat('dd MMMM yyyy').format(entry.salaryDate)}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.textDarkSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.pastelBlue,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Text(
                  entry.amount.toRupiah,
                  style: AppTheme.monoCurrency(
                    color: AppTheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Budgets List for this period
          Expanded(
            child: FutureBuilder<List<MonthlyBudget>>(
              future: salaryRepo.getMonthlyBudgets(
                periodMonth: entry.periodMonth,
                periodYear: entry.periodYear,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Gagal memuat rincian budget: ${snapshot.error}',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.danger,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final budgets = snapshot.data ?? [];
                if (budgets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 40, color: AppTheme.textDarkMuted),
                          const SizedBox(height: 8),
                          Text(
                            'Tidak ada rincian budget tersimpan untuk periode ini.',
                            style: GoogleFonts.dmSans(
                              color: AppTheme.textDarkSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final totalAllocated = budgets.fold<int>(
                    0, (sum, b) => sum + b.allocatedAmount);
                final totalSpent =
                    budgets.fold<int>(0, (sum, b) => sum + b.spentAmount);

                return ListView(
                  children: [
                    // Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLightAlt,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.borderLightSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Terencana',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.textDarkSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  totalAllocated.toRupiah,
                                  style: AppTheme.monoCurrency(
                                    fontSize: 13,
                                    color: AppTheme.textDarkPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: AppTheme.borderLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Terpakai',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.textDarkSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  totalSpent.toRupiah,
                                  style: AppTheme.monoCurrency(
                                    fontSize: 13,
                                    color: totalSpent > totalAllocated
                                        ? AppTheme.danger
                                        : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Rincian Pos Budget (${budgets.length} Kategori):',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ...budgets.map((b) {
                      final catName = b.categoryName ?? 'Kategori';
                      final catIcon = b.categoryIcon ?? 'category';
                      final catColor = _parseColor(b.categoryColor);
                      final pct = b.allocatedAmount > 0
                          ? (b.spentAmount / b.allocatedAmount).clamp(0.0, 1.0)
                          : 0.0;
                      final isOver = b.spentAmount > b.allocatedAmount;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _parseIcon(catIcon),
                                    size: 16,
                                    color: catColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    catName,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: AppTheme.textDarkPrimary,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      b.allocatedAmount.toRupiah,
                                      style: AppTheme.monoCurrency(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textDarkPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Terpakai: ${b.spentAmount.toRupiah}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: isOver
                                            ? AppTheme.danger
                                            : AppTheme.textDarkMuted,
                                        fontWeight: isOver
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 4,
                                backgroundColor: AppTheme.borderLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOver ? AppTheme.danger : catColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Action button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onEditForm();
            },
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Edit / Gunakan Periode Ini di Form'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppTheme.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('0xFF$clean'));
    } catch (_) {
      return AppTheme.primary;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'shopping_bag':
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'restaurant':
      case 'food':
        return Icons.restaurant_rounded;
      case 'home':
      case 'house':
        return Icons.home_rounded;
      case 'savings':
        return Icons.savings_outlined;
      case 'credit_card':
      case 'debt':
        return Icons.credit_card_outlined;
      case 'directions_car':
      case 'transport':
        return Icons.directions_car_outlined;
      case 'medical':
      case 'health':
        return Icons.medical_services_outlined;
      case 'movie':
      case 'entertainment':
        return Icons.movie_outlined;
      default:
        return Icons.category_rounded;
    }
  }
}
