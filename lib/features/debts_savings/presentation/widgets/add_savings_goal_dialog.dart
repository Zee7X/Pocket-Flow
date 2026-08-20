// lib/features/debts_savings/presentation/widgets/add_savings_goal_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
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
  final _currentAmountCtrl = TextEditingController(text: '0');
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
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      title: Text(
        'Tambah Target Tabungan',
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
              TextFormField(
                controller: _nameCtrl,
                style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Nama Target',
                  hintText: 'misal: Dana Darurat 3 Bulan, Liburan',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<GoalType>(
                initialValue: _goalType,
                decoration: const InputDecoration(labelText: 'Tipe Target'),
                items: GoalType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _goalType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _targetAmountCtrl,
                keyboardType: TextInputType.number,
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Target Dana (Rp)',
                  hintText: '10000000',
                  prefixText: 'Rp ',
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Target harus > 0' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _currentAmountCtrl,
                keyboardType: TextInputType.number,
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Dana Terkumpul Saat Ini (Rp)',
                  prefixText: 'Rp ',
                ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.tertiary,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final target = int.parse(_targetAmountCtrl.text.replaceAll('.', ''));
    final current = int.tryParse(_currentAmountCtrl.text.replaceAll('.', '')) ?? 0;

    ref.read(savingsGoalsProvider.notifier).addSavingsGoal(
          name: _nameCtrl.text.trim(),
          goalType: _goalType,
          targetAmount: target,
          currentAmount: current,
        );

    Navigator.pop(context);
  }
}
