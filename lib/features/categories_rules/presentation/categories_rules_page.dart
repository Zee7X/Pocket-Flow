// lib/features/categories_rules/presentation/categories_rules_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../domain/allocation_rule.dart';
import '../domain/category.dart';
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
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            tooltip: 'Pilih Template Bawaan',
            onPressed: () => _openTemplatePicker(context),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.pastelBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: AppTheme.primary),
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
          indicatorWeight: 2.5,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDarkMuted,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
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
      error: (e, _) => Center(child: Text('Error: $e')),
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

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: rules.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final rule = rules[i];
              final isZeroOrUnset = (rule.allocationType == AllocationType.fixed ||
                      rule.allocationType == AllocationType.capped) &&
                  rule.fixedAmount == 0;

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () => _openEditRule(context, categories, rule),
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
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
                      const SizedBox(width: 14),

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
                                      fontSize: 15,
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
                                fontSize: 13,
                                color: isZeroOrUnset
                                    ? AppTheme.primary
                                    : AppTheme.textDarkSecondary,
                                fontWeight: isZeroOrUnset
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppTheme.textDarkMuted),
                        tooltip: 'Atur / Edit Aturan',
                        onPressed: () => _openEditRule(context, categories, rule),
                      ),

                      // Active Switch & Delete
                      Switch(
                        value: rule.isActive,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) => ref
                            .read(allocationRulesProvider.notifier)
                            .toggleActive(rule.id, val),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.textDarkMuted),
                        tooltip: 'Hapus Aturan',
                        onPressed: () => ref
                            .read(allocationRulesProvider.notifier)
                            .deleteRule(rule.id),
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
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.category_rounded,
            title: 'Belum Ada Kategori',
            description: 'Buat kategori pengeluaran, tabungan, atau gunakan template bawaan.',
            actionLabel: 'Gunakan Template',
            onAction: () => _openTemplatePicker(context),
          );
        }

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final cat = categories[i];
              return CloudPulseCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(cat.type).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Icon(
                        _getCategoryIcon(cat.type),
                        size: 18,
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
                          Text(
                            _getCategoryTypeLabel(cat.type),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.textDarkMuted),
                      tooltip: 'Hapus Kategori',
                      onPressed: () => ref
                          .read(categoriesProvider.notifier)
                          .deleteCategory(cat.id),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatRuleFormula(AllocationRule rule) {
    switch (rule.allocationType) {
      case AllocationType.fixed:
        return rule.fixedAmount > 0
            ? 'Nominal: ${rule.fixedAmount.toRupiah}'
            : 'Rp0 (Ketuk untuk atur nominal)';
      case AllocationType.percentage:
        final pct = (rule.percentage ?? 0).toStringAsFixed(0);
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
        final pct = (rule.percentage ?? 0).toStringAsFixed(0);
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
}
