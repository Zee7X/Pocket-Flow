// lib/features/salary_allocation/presentation/widgets/salary_history_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../domain/monthly_budget.dart';
import '../../domain/salary_entry.dart';
import '../providers/salary_allocation_provider.dart';

class SalaryHistoryDetailSheet extends ConsumerStatefulWidget {
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
  ConsumerState<SalaryHistoryDetailSheet> createState() =>
      _SalaryHistoryDetailSheetState();
}

class _SalaryHistoryDetailSheetState
    extends ConsumerState<SalaryHistoryDetailSheet> {
  int _refreshKey = 0;

  void _triggerRefresh() {
    setState(() {
      _refreshKey++;
    });
  }

  void _openEditCategoryDialog(MonthlyBudget budget) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _EditCategoryBudgetDialog(
        budget: budget,
        periodMonth: widget.entry.periodMonth,
        periodYear: widget.entry.periodYear,
        onSaved: _triggerRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          periodStr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textDarkPrimary,
                          ),
                        ),
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
              const SizedBox(width: 8),
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
              key: ValueKey(_refreshKey),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rincian Pos Budget (${budgets.length} Kategori):',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkSecondary,
                          ),
                        ),
                        Text(
                          'Klik untuk ubah',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openEditCategoryDialog(b),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              border: Border.all(
                                color: isOver
                                    ? AppTheme.danger.withValues(alpha: 0.4)
                                    : AppTheme.borderLight,
                              ),
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            catName,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: AppTheme.textDarkPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 11,
                                                  color: AppTheme.textDarkMuted),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Ubah Budget',
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 10,
                                                  color: AppTheme.primary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
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
                          ),
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
              widget.onEditForm();
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

class _EditCategoryBudgetDialog extends ConsumerStatefulWidget {
  final MonthlyBudget budget;
  final int periodMonth;
  final int periodYear;
  final VoidCallback onSaved;

  const _EditCategoryBudgetDialog({
    required this.budget,
    required this.periodMonth,
    required this.periodYear,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditCategoryBudgetDialog> createState() =>
      _EditCategoryBudgetDialogState();
}

class _EditCategoryBudgetDialogState
    extends ConsumerState<_EditCategoryBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  bool _updateMasterRule = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: CurrencyInputFormatter.format(widget.budget.allocatedAmount),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final newAmount = CurrencyInputFormatter.parse(_amountCtrl.text);

    setState(() => _isSaving = true);
    try {
      await ref
          .read(salaryAllocationActionProvider.notifier)
          .updateCategoryBudget(
            categoryId: widget.budget.categoryId,
            periodMonth: widget.periodMonth,
            periodYear: widget.periodYear,
            newAllocatedAmount: newAmount,
            updateMasterRule: _updateMasterRule,
          );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        AppTheme.showSuccessSnackBar(
          context,
          'Budget ${widget.budget.categoryName ?? "Kategori"} berhasil diubah menjadi ${newAmount.toRupiah}!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppTheme.showErrorSnackBar(
          context,
          'Gagal mengubah budget: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.budget.categoryName ?? 'Kategori';
    final periodStr = DateFormat('MMMM yyyy')
        .format(DateTime(widget.periodYear, widget.periodMonth));

    return AlertDialog(
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ubah Budget',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLightAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.borderLightSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textDarkPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Periode: $periodStr',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.textDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Terpakai Saat Ini:',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.textDarkMuted,
                          ),
                        ),
                        Text(
                          widget.budget.spentAmount.toRupiah,
                          style: AppTheme.monoCurrency(
                            fontSize: 11.5,
                            color: widget.budget.spentAmount >
                                    widget.budget.allocatedAmount
                                ? AppTheme.danger
                                : AppTheme.textDarkPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Nominal Budget Baru (Rp)',
                  hintText: 'misal: 250.000',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final val = CurrencyInputFormatter.parse(v);
                  if (val < 0) return 'Nominal tidak boleh negatif';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () =>
                    setState(() => _updateMasterRule = !_updateMasterRule),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _updateMasterRule,
                        activeColor: AppTheme.primary,
                        onChanged: (val) =>
                            setState(() => _updateMasterRule = val ?? true),
                      ),
                      Expanded(
                        child: Text(
                          'Perbarui juga di Aturan Master Alokasi (untuk bulan-bulan berikutnya)',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.textDarkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan Budget'),
        ),
      ],
    );
  }
}

