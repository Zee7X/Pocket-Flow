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

  @override
  void initState() {
    super.initState();
    final init = widget.initialRule;
    if (init != null) {
      _nameCtrl = TextEditingController(text: init.name);
      _amountCtrl = TextEditingController(
        text: init.fixedAmount > 0 ? init.fixedAmount.toString() : '',
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
      _priorityCtrl = TextEditingController(text: '1');
      _selectedType = AllocationType.fixed;
      _selectedBase = PercentageBase.remaining;
      _isRequired = false;
      if (widget.categories.isNotEmpty) {
        _selectedCategoryId = widget.categories.first.id;
        _nameCtrl.text = widget.categories.first.name;
      }
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
    final isEditing = widget.initialRule != null;

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
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: widget.categories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      c.name,
                      style: GoogleFonts.dmSans(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategoryId = val;
                    if (!isEditing) {
                      final cat = widget.categories.firstWhere((c) => c.id == val);
                      _nameCtrl.text = cat.name;
                    }
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
                isExpanded: true,
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Tipe Alokasi'),
                items: const [
                  DropdownMenuItem(
                    value: AllocationType.fixed,
                    child: Text('Nominal Tetap (Fixed)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.capped,
                    child: Text('Batas Maksimal (Capped)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.percentage,
                    child: Text('Persentase (%)', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: AllocationType.remaining,
                    child: Text('Sisa Penghasilan (Remaining)', overflow: TextOverflow.ellipsis),
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
                  style: AppTheme.monoCurrency(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: _selectedType == AllocationType.fixed
                        ? 'Nominal Pasti (Rp)'
                        : 'Batas Maksimal (Rp)',
                    hintText: 'misal: 1500000',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    final clean = v?.replaceAll('.', '').replaceAll(',', '') ?? '';
                    final val = int.tryParse(clean);
                    if (val == null || val <= 0) return 'Nominal harus > 0';
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
                DropdownButtonFormField<PercentageBase>(
                  isExpanded: true,
                  initialValue: _selectedBase,
                  decoration: const InputDecoration(labelText: 'Dihitung Dari'),
                  items: const [
                    DropdownMenuItem(
                      value: PercentageBase.remaining,
                      child: Text('Sisa Penghasilan', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: PercentageBase.totalIncome,
                      child: Text('Total Gaji Masuk', overflow: TextOverflow.ellipsis),
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
                style: GoogleFonts.robotoMono(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Urutan Prioritas (#)',
                  hintText: '1 (Diproses pertama)',
                ),
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final fixedAmount = int.tryParse(
          _amountCtrl.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    final percentage = double.tryParse(_pctCtrl.text);
    final priority = int.tryParse(_priorityCtrl.text) ?? 1;
    final isEditing = widget.initialRule != null;

    if (isEditing) {
      ref.read(allocationRulesProvider.notifier).updateRule(
            id: widget.initialRule!.id,
            categoryId: _selectedCategoryId!,
            name: _nameCtrl.text.trim(),
            allocationType: _selectedType,
            fixedAmount: fixedAmount,
            percentage: percentage,
            percentageBase: _selectedBase,
            priority: priority,
            isRequired: _isRequired,
          );
    } else {
      ref.read(allocationRulesProvider.notifier).addRule(
            categoryId: _selectedCategoryId!,
            name: _nameCtrl.text.trim(),
            allocationType: _selectedType,
            fixedAmount: fixedAmount,
            percentage: percentage,
            percentageBase: _selectedBase,
            priority: priority,
            isRequired: _isRequired,
          );
    }

    Navigator.pop(context);
  }
}
