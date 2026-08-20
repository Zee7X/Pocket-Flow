// lib/features/debts_savings/presentation/widgets/record_savings_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../domain/savings_goal.dart';
import '../../domain/savings_transaction.dart';
import '../providers/debts_savings_provider.dart';

class RecordSavingsDialog extends ConsumerStatefulWidget {
  final SavingsGoal goal;

  const RecordSavingsDialog({super.key, required this.goal});

  @override
  ConsumerState<RecordSavingsDialog> createState() =>
      _RecordSavingsDialogState();
}

class _RecordSavingsDialogState extends ConsumerState<RecordSavingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SavingsTransactionType _type = SavingsTransactionType.deposit;
  final _date = DateTime.now();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
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
        'Setor / Tarik Tabungan',
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
            Text(
              'Target: ${widget.goal.name}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),

            // Deposit or Withdrawal switch
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Setor Dana', style: GoogleFonts.dmSans())),
                    selected: _type == SavingsTransactionType.deposit,
                    selectedColor: AppTheme.tertiary.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: _type == SavingsTransactionType.deposit
                          ? AppTheme.tertiary
                          : AppTheme.textDarkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (v) {
                      if (v) setState(() => _type = SavingsTransactionType.deposit);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text('Tarik Dana', style: GoogleFonts.dmSans())),
                    selected: _type == SavingsTransactionType.withdrawal,
                    selectedColor: AppTheme.warning.withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: _type == SavingsTransactionType.withdrawal
                          ? AppTheme.warning
                          : AppTheme.textDarkMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (v) {
                      if (v) setState(() => _type = SavingsTransactionType.withdrawal);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: AppTheme.monoCurrency(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final clean = v?.replaceAll('.', '') ?? '';
                final val = int.tryParse(clean);
                if (val == null || val <= 0) return 'Nominal harus > 0';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _noteCtrl,
              style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'misal: Sisihan bonus',
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
            backgroundColor: _type == SavingsTransactionType.deposit
                ? AppTheme.tertiary
                : AppTheme.warning,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountCtrl.text.replaceAll('.', ''));

    ref.read(savingsGoalsProvider.notifier).recordSavingsTransaction(
          savingsGoalId: widget.goal.id,
          type: _type,
          amount: amount,
          transactionDate: _date,
          note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
        );

    Navigator.pop(context);
  }
}
