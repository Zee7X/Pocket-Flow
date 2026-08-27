// lib/features/debts_savings/presentation/widgets/record_savings_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/utils/error_helper.dart';
import '../../../categories_rules/domain/category.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
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
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        'Setor / Tarik: ${widget.goal.name}',
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
              // Segmented Type Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: const Center(child: Text('Setor (Tambah)')),
                      selected: _type == SavingsTransactionType.deposit,
                      selectedColor: AppTheme.tertiary,
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: GoogleFonts.dmSans(
                        color: _type == SavingsTransactionType.deposit
                            ? Colors.white
                            : AppTheme.textDarkSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      onSelected: (v) {
                        if (v) setState(() => _type = SavingsTransactionType.deposit);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      showCheckmark: false,
                      label: const Center(child: Text('Tarik Dana')),
                      selected: _type == SavingsTransactionType.withdrawal,
                      selectedColor: AppTheme.warning,
                      backgroundColor: AppTheme.surfaceLight,
                      labelStyle: GoogleFonts.dmSans(
                        color: _type == SavingsTransactionType.withdrawal
                            ? Colors.white
                            : AppTheme.textDarkSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: 'misal: 500.000',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final val = CurrencyInputFormatter.parse(v);
                  if (val <= 0) return 'Nominal harus > 0';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyInputFormatter.parse(_amountCtrl.text);
    final isDeposit = _type == SavingsTransactionType.deposit;

    try {
      await ref.read(savingsGoalsProvider.notifier).recordSavingsTransaction(
            savingsGoalId: widget.goal.id,
            type: _type,
            amount: amount,
            transactionDate: _date,
            note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
          );

      // Auto sync deposit to transactions (records an expense in saving category)
      if (isDeposit) {
        try {
          final categories = ref.read(categoriesProvider).value ?? [];
          final isEmergency = widget.goal.goalType == GoalType.emergencyFund;
          final savingCategory = categories.cast<Category?>().firstWhere(
            (c) =>
                c != null &&
                ((isEmergency && c.name.toLowerCase().contains('darurat')) ||
                    (!isEmergency && c.name.toLowerCase().contains('tabung')) ||
                    c.name.toLowerCase().contains('saving') ||
                    c.name.toLowerCase().contains('invest')),
            orElse: () => categories.cast<Category?>().firstWhere(
              (c) =>
                  c != null &&
                  (c.name.toLowerCase().contains('tabung') ||
                      c.name.toLowerCase().contains('darurat')),
              orElse: () => categories.isNotEmpty ? categories.first : null,
            ),
          );

          if (savingCategory != null) {
            await ref.read(transactionsProvider.notifier).addTransaction(
                  categoryId: savingCategory.id,
                  type: TransactionType.expense,
                  amount: amount,
                  transactionDate: _date,
                  description:
                      'Setor: ${widget.goal.name}${_noteCtrl.text.isNotEmpty ? " (${_noteCtrl.text})" : ""}',
                  paymentMethod: 'Transfer Bank',
                );
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          isDeposit
              ? 'Setoran tabungan & transaksi berhasil dicatat!'
              : 'Penarikan tabungan berhasil dicatat!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal mencatat transaksi tabungan. Silakan coba lagi.'),
        );
      }
    }
  }
}
