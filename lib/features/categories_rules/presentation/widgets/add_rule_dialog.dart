// lib/features/categories_rules/presentation/widgets/add_rule_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../domain/allocation_rule.dart';
import '../../domain/category.dart';
import '../providers/categories_rules_provider.dart';

class AddRuleDialog extends ConsumerStatefulWidget {
  final List<Category> categories;
  const AddRuleDialog({super.key, required this.categories});

  @override
  ConsumerState<AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends ConsumerState<AddRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _pctCtrl = TextEditingController();
  final _priorityCtrl = TextEditingController(text: '1');

  String? _selectedCategoryId;
  AllocationType _selectedType = AllocationType.fixed;
  PercentageBase _selectedBase = PercentageBase.remaining;
  bool _isRequired = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
      _nameCtrl.text = widget.categories.first.name;
    }
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
    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      title: Text(
        'Tambah Aturan Alokasi',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDarkPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: widget.categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: GoogleFonts.dmSans()),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                    final cat = widget.categories.firstWhere((c) => c.id == val);
                    _nameCtrl.text = cat.name;
                  });
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(labelText: 'Nama Aturan'),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              // Allocation Type
              DropdownButtonFormField<AllocationType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Tipe Alokasi'),
                items: const [
                  DropdownMenuItem(value: AllocationType.fixed, child: Text('Nominal Tetap (Fixed)')),
                  DropdownMenuItem(value: AllocationType.percentage, child: Text('Persentase (%)')),
                  DropdownMenuItem(value: AllocationType.capped, child: Text('Maksimal (Capped)')),
                  DropdownMenuItem(value: AllocationType.remaining, child: Text('Semua Sisa (Remaining)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 14),

              if (_selectedType == AllocationType.fixed || _selectedType == AllocationType.capped) ...[
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nominal (Rp)',
                    hintText: 'misal: 850000',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Nominal harus > 0' : null,
                ),
                const SizedBox(height: 14),
              ],

              if (_selectedType == AllocationType.percentage) ...[
                TextFormField(
                  controller: _pctCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Persentase (%)',
                    hintText: 'misal: 10, 20, 50',
                    suffixText: '%',
                  ),
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d <= 0 || d > 100) return 'Persentase 1 - 100%';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<PercentageBase>(
                  initialValue: _selectedBase,
                  decoration: const InputDecoration(labelText: 'Dihitung Dari'),
                  items: const [
                    DropdownMenuItem(value: PercentageBase.remaining, child: Text('Sisa Penghasilan')),
                    DropdownMenuItem(value: PercentageBase.totalIncome, child: Text('Total Gaji')),
                    DropdownMenuItem(value: PercentageBase.extraIncome, child: Text('Bonus / Extra Income')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedBase = val);
                  },
                ),
                const SizedBox(height: 14),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priorityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prioritas (Urutan)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Wajib', style: GoogleFonts.dmSans(fontSize: 13)),
                      value: _isRequired,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _isRequired = v ?? false),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) return;

    final fixed = int.tryParse(_amountCtrl.text.replaceAll('.', '')) ?? 0;
    final pct = double.tryParse(_pctCtrl.text);
    final priority = int.tryParse(_priorityCtrl.text) ?? 1;

    ref.read(allocationRulesProvider.notifier).addRule(
          categoryId: _selectedCategoryId!,
          name: _nameCtrl.text.trim(),
          allocationType: _selectedType,
          fixedAmount: fixed,
          percentage: pct,
          percentageBase: _selectedBase,
          priority: priority,
          isRequired: _isRequired,
        );
    Navigator.pop(context);
  }
}
