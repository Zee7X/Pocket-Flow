// lib/features/categories_rules/presentation/categories_rules_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../domain/allocation_rule.dart';
import '../domain/category.dart';
import '../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import 'providers/categories_rules_provider.dart';
import 'widgets/add_category_dialog.dart';
import 'widgets/add_rule_dialog.dart';
import 'widgets/template_picker_dialog.dart';

class CategoriesRulesPage extends ConsumerStatefulWidget {
  const CategoriesRulesPage({super.key});

  @override
  ConsumerState<CategoriesRulesPage> createState() =>
      _CategoriesRulesPageState();
}

class _CategoriesRulesPageState extends ConsumerState<CategoriesRulesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(allocationRulesProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Aturan & Kategori',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.pastelBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Pilih Template Bawaan',
            onPressed: () => _openTemplatePicker(context),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: Colors.white),
            ),
            tooltip: 'Tambah Item',
            onPressed: () {
              if (_tabCtrl.index == 0) {
                _openAddRule(context, categoriesAsync.value ?? []);
              } else {
                _openAddCategory(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDarkMuted,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Aturan Alokasi'),
            Tab(text: 'Daftar Kategori'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 1: Allocation Rules ─────────────────────────────────────
            _buildRulesTab(rulesAsync, categoriesAsync.value ?? []),

            // ── Tab 2: Categories ───────────────────────────────────────────
            _buildCategoriesTab(categoriesAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesTab(
    AsyncValue<List<AllocationRule>> rulesAsync,
    List<Category> categories,
  ) {
    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () async {
          ref.invalidate(allocationRulesProvider);
        },
      ),
      data: (rules) {
        if (rules.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.tune_rounded,
            title: 'Belum Ada Aturan Alokasi',
            description:
                'Tentukan bagaimana penghasilanmu dibagi otomatis setiap kali gajian masuk.',
            actionLabel: 'Pilih Template Bawaan',
            onAction: () => _openTemplatePicker(context),
          );
        }

        final sortedRules = [...rules]
          ..sort((a, b) => a.priority.compareTo(b.priority));

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: sortedRules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final rule = sortedRules[i];
              final isZeroOrUnset = (rule.allocationType == AllocationType.fixed ||
                      rule.allocationType == AllocationType.capped) &&
                  rule.fixedAmount == 0;

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () => _openEditRule(context, categories, rule),
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Priority Badge
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          '#${rule.priority}',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Rule Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    rule.name,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: rule.isActive
                                          ? AppTheme.textDarkPrimary
                                          : AppTheme.textDarkMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (rule.isRequired) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(AppTheme.radiusSmall),
                                    ),
                                    child: Text(
                                      'Wajib',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 10,
                                        color: AppTheme.danger,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatRuleFormula(rule),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: isZeroOrUnset
                                    ? AppTheme.primary
                                    : AppTheme.textDarkSecondary,
                                fontWeight: isZeroOrUnset
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Right-side compact controls
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Toggle Switch (compact)
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: rule.isActive,
                              activeThumbColor: AppTheme.primary,
                              onChanged: (val) => ref
                                  .read(allocationRulesProvider.notifier)
                                  .toggleActive(rule.id, val),
                            ),
                          ),
                          // Edit & Delete row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 16, color: AppTheme.textDarkMuted),
                                  tooltip: 'Edit',
                                  onPressed: () => _openEditRule(context, categories, rule),
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 16, color: AppTheme.textDarkMuted),
                                  tooltip: 'Hapus',
                                  onPressed: () => _deleteRule(rule),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(AsyncValue<List<Category>> categoriesAsync) {
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () async {
          ref.invalidate(categoriesProvider);
        },
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.category_rounded,
            title: 'Belum Ada Kategori',
            description: 'Tambahkan kategori baru atau pilih template bawaan.',
            actionLabel: 'Tambah Kategori',
            onAction: () => _openAddCategory(context),
          );
        }

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              final isExpense = cat.type == CategoryType.expense;

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                onTap: isExpense
                    ? () async {
                        await ref.read(categoriesProvider.notifier).toggleCategoryIsFixed(cat.id, !cat.isFixed);
                        ref.invalidate(monthlyBudgetsProvider);
                        if (mounted) {
                          AppTheme.showSuccessSnackBar(
                            context,
                            '"${cat.name}" diubah menjadi ${!cat.isFixed ? 'Biaya Tetap 📌' : 'Biaya Variabel (Harian) 📅'}',
                          );
                        }
                      }
                    : null,
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(cat.type).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(cat.type),
                          size: 20,
                          color: _getCategoryColor(cat.type),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _getCategoryTypeLabel(cat.type),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: AppTheme.textDarkSecondary,
                                  ),
                                ),
                                if (isExpense) ...[
                                  Text(
                                    ' • ',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppTheme.textDarkMuted,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: cat.isFixed
                                          ? AppTheme.surfaceLightAlt
                                          : AppTheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      cat.isFixed ? '📌 Tetap' : '📅 Harian',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: cat.isFixed
                                            ? AppTheme.textDarkMuted
                                            : AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.textDarkMuted),
                        tooltip: 'Hapus Kategori',
                        onPressed: () => _deleteCategory(cat),
                      ),
                    ],
                  ),
                ),
              );

            },
          ),
        );
      },
    );
  }

  String _formatPct(double? value) {
    if (value == null || value <= 0) return '0';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
  }

  String _formatRuleFormula(AllocationRule rule) {
    switch (rule.allocationType) {
      case AllocationType.fixed:
        return rule.fixedAmount > 0
            ? 'Nominal: ${rule.fixedAmount.toRupiah}'
            : 'Rp0 (Ketuk untuk atur nominal)';
      case AllocationType.percentage:
        final pct = _formatPct(rule.percentage);
        final base = _getBaseLabel(rule.percentageBase);
        return (rule.percentage ?? 0) > 0
            ? '$pct% dari $base'
            : '0% dari $base (Ketuk untuk atur %)';
      case AllocationType.capped:
        return rule.fixedAmount > 0
            ? 'Maksimal ${rule.fixedAmount.toRupiah}'
            : 'Maksimal Rp0 (Ketuk untuk atur batas)';
      case AllocationType.remaining:
        return 'Semua sisa penghasilan (100%)';
      case AllocationType.proportional:
        final pct = _formatPct(rule.percentage);
        return 'Proporsional $pct%';
    }
  }

  String _getBaseLabel(PercentageBase base) {
    switch (base) {
      case PercentageBase.totalIncome:
        return 'Total Gaji';
      case PercentageBase.extraIncome:
        return 'Bonus / Extra';
      case PercentageBase.remaining:
        return 'Sisa Penghasilan';
    }
  }

  Color _getCategoryColor(CategoryType type) {
    switch (type) {
      case CategoryType.expense:
        return AppTheme.warning;
      case CategoryType.income:
        return AppTheme.success;
      case CategoryType.savings:
        return AppTheme.tertiary;
      case CategoryType.debt:
        return AppTheme.danger;
    }
  }

  IconData _getCategoryIcon(CategoryType type) {
    switch (type) {
      case CategoryType.expense:
        return Icons.shopping_bag_outlined;
      case CategoryType.income:
        return Icons.attach_money_rounded;
      case CategoryType.savings:
        return Icons.savings_outlined;
      case CategoryType.debt:
        return Icons.credit_card_outlined;
    }
  }

  String _getCategoryTypeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.expense:
        return 'Pengeluaran';
      case CategoryType.income:
        return 'Pemasukan';
      case CategoryType.savings:
        return 'Tabungan & Dana Darurat';
      case CategoryType.debt:
        return 'Utang / Cicilan';
    }
  }

  void _openTemplatePicker(BuildContext context) {
    showDialog(context: context, builder: (_) => const TemplatePickerDialog());
  }

  void _openAddCategory(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddCategoryDialog());
  }

  void _openAddRule(BuildContext context, List<Category> categories) {
    if (categories.isEmpty) {
      AppTheme.showErrorSnackBar(context, 'Buat kategori terlebih dahulu');
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AddRuleDialog(categories: categories),
    );
  }

  void _openEditRule(
      BuildContext context, List<Category> categories, AllocationRule rule) {
    showDialog(
      context: context,
      builder: (_) => AddRuleDialog(
        categories: categories,
        initialRule: rule,
      ),
    );
  }

  Future<void> _deleteCategory(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          side: const BorderSide(color: AppTheme.borderLightSubtle),
        ),
        title: Text(
          'Hapus Kategori?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus kategori "${cat.name}"? Kategori yang sudah memiliki transaksi atau aturan alokasi tidak dapat dihapus.',
          style: GoogleFonts.dmSans(
            color: AppTheme.textDarkSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(categoriesProvider.notifier).deleteCategory(cat.id);
        if (mounted) {
          AppTheme.showSuccessSnackBar(
            context,
            'Kategori "${cat.name}" berhasil dihapus.',
          );
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showErrorSnackBar(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }

  Future<void> _deleteRule(AllocationRule rule) async {
    try {
      await ref.read(allocationRulesProvider.notifier).deleteRule(rule.id);
      if (mounted) {
        AppTheme.showSuccessSnackBar(
          context,
          'Aturan "${rule.name}" berhasil dihapus.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}
