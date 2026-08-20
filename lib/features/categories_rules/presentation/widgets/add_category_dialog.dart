// lib/features/categories_rules/presentation/widgets/add_category_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../domain/category.dart';
import '../providers/categories_rules_provider.dart';

class AddCategoryDialog extends ConsumerStatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  ConsumerState<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  CategoryType _selectedType = CategoryType.expense;

  @override
  void dispose() {
    _nameCtrl.dispose();
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
        'Tambah Kategori Baru',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppTheme.textDarkPrimary,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
              decoration: const InputDecoration(
                labelText: 'Nama Kategori',
                hintText: 'misal: Belanja Bulanan, Kuota, dll',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nama kategori wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Tipe Kategori',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: CategoryType.values.map((type) {
                final isSelected = _selectedType == type;
                return ChoiceChip(
                  label: Text(_getTypeLabel(type)),
                  selected: isSelected,
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceDarkAlt,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedType = type);
                  },
                );
              }).toList(),
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
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  String _getTypeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.expense:
        return 'Pengeluaran';
      case CategoryType.income:
        return 'Pemasukan';
      case CategoryType.savings:
        return 'Tabungan';
      case CategoryType.debt:
        return 'Utang / Cicilan';
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(categoriesProvider.notifier).addCategory(
          name: _nameCtrl.text.trim(),
          type: _selectedType,
        );
    Navigator.pop(context);
  }
}
