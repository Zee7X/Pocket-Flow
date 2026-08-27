// lib/features/categories_rules/presentation/widgets/add_category_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/error_helper.dart';
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
  bool _isFixed = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        'Tambah Kategori Baru',
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              // 2x2 Modern Category Type Cards Grid
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeCard(
                          type: CategoryType.expense,
                          label: 'Pengeluaran',
                          icon: Icons.arrow_upward_rounded,
                          activeColor: AppTheme.danger,
                          activeBg: const Color(0xFFFEF2F2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeCard(
                          type: CategoryType.income,
                          label: 'Pemasukan',
                          icon: Icons.arrow_downward_rounded,
                          activeColor: AppTheme.success,
                          activeBg: const Color(0xFFECFDF5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeCard(
                          type: CategoryType.savings,
                          label: 'Tabungan',
                          icon: Icons.savings_rounded,
                          activeColor: AppTheme.tertiary,
                          activeBg: const Color(0xFFF3E8FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTypeCard(
                          type: CategoryType.debt,
                          label: 'Utang / Cicilan',
                          icon: Icons.credit_card_rounded,
                          activeColor: AppTheme.warning,
                          activeBg: const Color(0xFFFEF3C7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Biaya Tetap toggle (only for expense) ────────────────────
              if (_selectedType == CategoryType.expense) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isFixed
                        ? AppTheme.surfaceLightAlt
                        : AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: _isFixed
                          ? AppTheme.borderLight
                          : AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFixed
                            ? Icons.push_pin_rounded
                            : Icons.today_rounded,
                        size: 18,
                        color: _isFixed
                            ? AppTheme.textDarkMuted
                            : AppTheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Biaya Tetap?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkPrimary,
                              ),
                            ),
                            Text(
                              _isFixed
                                  ? 'Kos, listrik — tidak perlu estimasi harian'
                                  : 'Makan, transport — tampil estimasi per hari',
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
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required CategoryType type,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = _selectedType == type;

    return Material(
      color: isSelected ? activeBg : AppTheme.surfaceLightAlt,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: isSelected ? activeColor : AppTheme.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : AppTheme.textDarkMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeColor : AppTheme.textDarkSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    try {
      await ref.read(categoriesProvider.notifier).addCategory(
            name: name,
            type: _selectedType,
            isFixed: _selectedType == CategoryType.expense ? _isFixed : false,
          );
      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Kategori "$name" berhasil ditambahkan!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menambahkan kategori. Silakan coba lagi.'),
        );
      }
    }
  }
}
