// lib/features/categories_rules/presentation/widgets/add_rule_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/utils/error_helper.dart';
import '../../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../domain/allocation_rule.dart';
import '../../domain/category.dart';
import '../providers/categories_rules_provider.dart';

class AddRuleDialog extends ConsumerStatefulWidget {
  final List<Category> categories;
  final AllocationRule? initialRule;

  const AddRuleDialog({
    super.key,
    required this.categories,
    this.initialRule,
  });

  @override
  ConsumerState<AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends ConsumerState<AddRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _pctCtrl;
  late final TextEditingController _priorityCtrl;

  String? _selectedCategoryId;
  late AllocationType _selectedType;
  late PercentageBase _selectedBase;
  late bool _isRequired;
  bool _isFixed = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialRule;
    if (init != null) {
      _nameCtrl = TextEditingController(text: init.name);
      _amountCtrl = TextEditingController(
        text: init.fixedAmount > 0
            ? CurrencyInputFormatter.format(init.fixedAmount)
            : '',
      );
      _pctCtrl = TextEditingController(
        text: init.percentage != null && init.percentage! > 0
            ? init.percentage!.toStringAsFixed(0)
            : '',
      );
      _priorityCtrl = TextEditingController(text: init.priority.toString());
      _selectedCategoryId = init.categoryId;
      _selectedType = init.allocationType;
      _selectedBase = init.percentageBase;
      _isRequired = init.isRequired;
    } else {
      _nameCtrl = TextEditingController();
      _amountCtrl = TextEditingController();
      _pctCtrl = TextEditingController();
      _selectedType = AllocationType.fixed;
      _selectedBase = PercentageBase.remaining;
      _isRequired = false;
      if (widget.categories.isNotEmpty) {
        _selectedCategoryId = widget.categories.first.id;
      }
      final existingRules = ref.read(allocationRulesProvider).value ?? [];
      final nextPriority = existingRules.isEmpty
          ? 1
          : (existingRules.map((r) => r.priority).reduce((a, b) => a > b ? a : b) + 1);
      _priorityCtrl = TextEditingController(text: nextPriority.toString());
    }

    final cat = widget.categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
    _isFixed = cat?.isFixed ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _pctCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRule != null;
    final selectedCat = widget.categories.where((c) => c.id == _selectedCategoryId).firstOrNull;

    return AlertDialog(
      scrollable: true,
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        isEditing ? 'Atur Alokasi: ${widget.initialRule!.name}' : 'Tambah Aturan Alokasi',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppTheme.textDarkPrimary,
        ),
      ),
      content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              AppDropdownFormField<String>(
                value: _selectedCategoryId,
                labelText: 'Kategori',
                hintText: 'Pilih Kategori',
                prefixIcon: const Icon(Icons.category_outlined, size: 20, color: AppTheme.primary),
                items: widget.categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: AppDropdownItemContent(
                      icon: c.isFixed ? Icons.push_pin_rounded : Icons.folder_outlined,
                      iconColor: c.isFixed ? AppTheme.warning : AppTheme.primary,
                      iconBgColor: c.isFixed ? AppTheme.pastelYellow : AppTheme.pastelBlue,
                      title: c.name,
                      badgeText: c.isFixed ? 'Tetap' : 'Variabel',
                      badgeColor: c.isFixed ? AppTheme.warning : AppTheme.primary,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                    final cat = widget.categories.where((c) => c.id == val).firstOrNull;
                    if (cat != null) {
                      _isFixed = cat.isFixed;
                    }
                  });
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Aturan',
                  hintText: 'misal: Bayar Kos, Tabungan Nikah',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // Allocation Type
              AppDropdownFormField<AllocationType>(
                value: _selectedType,
                labelText: 'Tipe Alokasi',
                prefixIcon: const Icon(Icons.tune_rounded, size: 20, color: AppTheme.primary),
                items: const [
                  DropdownMenuItem(
                    value: AllocationType.fixed,
                    child: AppDropdownItemContent(
                      icon: Icons.push_pin_rounded,
                      iconColor: AppTheme.warning,
                      iconBgColor: AppTheme.pastelYellow,
                      title: 'Nominal Tetap (Fixed)',
                      subtitle: 'Jumlah pasti tiap periode gajian',
                    ),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.capped,
                    child: AppDropdownItemContent(
                      icon: Icons.vertical_align_top_rounded,
                      iconColor: AppTheme.info,
                      iconBgColor: AppTheme.pastelBlue,
                      title: 'Batas Maksimal (Capped)',
                      subtitle: 'Maksimal alokasi hingga batas tertentu',
                    ),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.percentage,
                    child: AppDropdownItemContent(
                      icon: Icons.percent_rounded,
                      iconColor: AppTheme.primary,
                      iconBgColor: AppTheme.pastelBlue,
                      title: 'Persentase (%)',
                      subtitle: 'Dihitung dari persentase pemasukan',
                    ),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.remaining,
                    child: AppDropdownItemContent(
                      icon: Icons.savings_outlined,
                      iconColor: AppTheme.success,
                      iconBgColor: AppTheme.pastelGreen,
                      title: 'Sisa Penghasilan (Remaining)',
                      subtitle: 'Menampung sisa uang yang belum teralokasi',
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 14),

              // Fixed Amount Input
              if (_selectedType == AllocationType.fixed ||
                  _selectedType == AllocationType.capped) ...[
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                  style: AppTheme.monoCurrency(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: _selectedType == AllocationType.fixed
                        ? 'Nominal Pasti (Rp)'
                        : 'Batas Maksimal (Rp)',
                    hintText: 'misal: 1.500.000',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final val = CurrencyInputFormatter.parse(v);
                    if (val <= 0) return 'Nominal harus > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Percentage Input
              if (_selectedType == AllocationType.percentage) ...[
                TextFormField(
                  controller: _pctCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.robotoMono(color: AppTheme.textDarkPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Persentase (%)',
                    hintText: 'misal: 20',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0 || val > 100) {
                      return 'Persentase 1 - 100%';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                AppDropdownFormField<PercentageBase>(
                  value: _selectedBase,
                  labelText: 'Dihitung Dari',
                  prefixIcon: const Icon(Icons.calculate_outlined, size: 20, color: AppTheme.primary),
                  items: const [
                    DropdownMenuItem(
                      value: PercentageBase.remaining,
                      child: AppDropdownItemContent(
                        icon: Icons.savings_outlined,
                        iconColor: AppTheme.success,
                        iconBgColor: AppTheme.pastelGreen,
                        title: 'Sisa Penghasilan',
                        subtitle: 'Dihitung dari sisa setelah pos wajib',
                      ),
                    ),
                    DropdownMenuItem(
                      value: PercentageBase.totalIncome,
                      child: AppDropdownItemContent(
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppTheme.primary,
                        iconBgColor: AppTheme.pastelBlue,
                        title: 'Total Gaji Masuk',
                        subtitle: 'Dihitung dari total gaji bruto',
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _selectedBase = val!),
                ),
                const SizedBox(height: 14),
              ],

              // Priority
              TextFormField(
                controller: _priorityCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.robotoMono(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Urutan Prioritas (#)',
                  hintText: '1 (Diproses pertama)',
                  suffixIcon: Tooltip(
                    message: 'Nomor 1 diproses paling awal. Jika nomor sudah ada, posisi akan otomatis bertukar posisi.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textDarkMuted),
                  ),
                ),
                validator: (v) {
                  final p = int.tryParse(v ?? '');
                  if (p == null || p < 1) return 'Prioritas minimal 1';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Is Required Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Kategori Wajib',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                subtitle: Text(
                  'Peringatan jika sisa gaji tidak cukup untuk alokasi ini',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textDarkMuted,
                  ),
                ),
                value: _isRequired,
                activeThumbColor: AppTheme.danger,
                onChanged: (val) => setState(() => _isRequired = val),
              ),

              // ── Biaya Tetap (Fixed Cost) toggle for Expense categories ──
              if (selectedCat != null && selectedCat.type == CategoryType.expense) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isFixed
                        ? AppTheme.surfaceLightAlt
                        : AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: _isFixed
                          ? AppTheme.borderLight
                          : AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFixed ? Icons.push_pin_rounded : Icons.today_rounded,
                        size: 18,
                        color: _isFixed ? AppTheme.textDarkMuted : AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biaya Tetap (Fixed Cost)',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkPrimary,
                              ),
                            ),
                            Text(
                              _isFixed
                                  ? 'Kos, listrik, cicilan — tidak perlu estimasi kuota harian'
                                  : 'Makan, transport — tampil estimasi kuota per hari',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.textDarkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isFixed,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (val) => setState(() => _isFixed = val),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEditing ? 'Simpan Perubahan' : 'Simpan Aturan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final fixedAmount = CurrencyInputFormatter.parse(_amountCtrl.text);
    final percentage = double.tryParse(_pctCtrl.text);
    final priority = int.tryParse(_priorityCtrl.text) ?? 1;
    final isEditing = widget.initialRule != null;
    final ruleName = _nameCtrl.text.trim();

    try {
      if (isEditing) {
        await ref.read(allocationRulesProvider.notifier).updateRule(
              id: widget.initialRule!.id,
              categoryId: _selectedCategoryId!,
              name: ruleName,
              allocationType: _selectedType,
              fixedAmount: fixedAmount,
              percentage: percentage,
              percentageBase: _selectedBase,
              priority: priority,
              isRequired: _isRequired,
            );
      } else {
        await ref.read(allocationRulesProvider.notifier).addRule(
              categoryId: _selectedCategoryId!,
              name: ruleName,
              allocationType: _selectedType,
              fixedAmount: fixedAmount,
              percentage: percentage,
              percentageBase: _selectedBase,
              priority: priority,
              isRequired: _isRequired,
            );
      }

      // Sync isFixed with category if changed
      final selectedCat = widget.categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
      if (selectedCat != null && selectedCat.isFixed != _isFixed) {
        await ref.read(categoriesProvider.notifier).toggleCategoryIsFixed(selectedCat.id, _isFixed);
        ref.invalidate(monthlyBudgetsProvider);
      }

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          isEditing
              ? 'Aturan "$ruleName" berhasil diperbarui!'
              : 'Aturan "$ruleName" berhasil ditambahkan!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menyimpan aturan. Silakan coba lagi.'),
        );
      }
    }
  }
}
