// lib/features/debts_savings/presentation/widgets/add_savings_goal_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/utils/error_helper.dart';
import '../../domain/savings_goal.dart';
import '../providers/debts_savings_provider.dart';

class AddSavingsGoalDialog extends ConsumerStatefulWidget {
  const AddSavingsGoalDialog({super.key});

  @override
  ConsumerState<AddSavingsGoalDialog> createState() =>
      _AddSavingsGoalDialogState();
}

class _AddSavingsGoalDialogState extends ConsumerState<AddSavingsGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetAmountCtrl = TextEditingController();
  final _currentAmountCtrl = TextEditingController();
  GoalType _goalType = GoalType.emergencyFund;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetAmountCtrl.dispose();
    _currentAmountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        'Tambah Target Tabungan',
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
                style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Target',
                  hintText: 'misal: Dana Darurat 6 Bulan, Beli Laptop',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              AppDropdownFormField<GoalType>(
                value: _goalType,
                labelText: 'Tipe Target Tabungan',
                prefixIcon: const Icon(Icons.savings_outlined, size: 20, color: AppTheme.success),
                items: GoalType.values.map((t) {
                  final IconData tIcon = switch (t) {
                    GoalType.emergencyFund => Icons.shield_outlined,
                    GoalType.saving => Icons.savings_outlined,
                    GoalType.purchase => Icons.shopping_cart_outlined,
                    GoalType.other => Icons.flag_outlined,
                  };
                  return DropdownMenuItem(
                    value: t,
                    child: AppDropdownItemContent(
                      icon: tIcon,
                      iconColor: AppTheme.success,
                      iconBgColor: AppTheme.pastelGreen,
                      title: t.displayName,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _goalType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _targetAmountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Target Dana (Rp)',
                  hintText: 'misal: 10.000.000',
                  prefixText: 'Rp ',
                ),
                validator: (v) =>
                    CurrencyInputFormatter.parse(v) <= 0 ? 'Target harus > 0' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _currentAmountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Dana Terkumpul Saat Ini (Rp)',
                  hintText: '0',
                  prefixText: 'Rp ',
                ),
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
            backgroundColor: AppTheme.tertiary,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final target = CurrencyInputFormatter.parse(_targetAmountCtrl.text);
    final current = CurrencyInputFormatter.parse(_currentAmountCtrl.text);
    final name = _nameCtrl.text.trim();

    try {
      await ref.read(savingsGoalsProvider.notifier).addSavingsGoal(
            name: name,
            goalType: _goalType,
            targetAmount: target,
            currentAmount: current,
          );

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Target tabungan "$name" berhasil dibuat!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal membuat target tabungan. Silakan coba lagi.'),
        );
      }
    }
  }
}
