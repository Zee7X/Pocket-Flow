// lib/features/debts_savings/presentation/widgets/record_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/utils/error_helper.dart';
import '../../../categories_rules/domain/category.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../domain/debt.dart';
import '../providers/debts_savings_provider.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final Debt debt;

  const RecordPaymentDialog({super.key, required this.debt});

  @override
  ConsumerState<RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _paymentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.debt.minimumPayment > 0) {
      _amountCtrl.text = CurrencyInputFormatter.format(widget.debt.minimumPayment);
    }
  }

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
        'Bayar Pinjaman: ${widget.debt.name}',
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
            // Sisa Pokok Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLightAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sisa Pokok Saat Ini:',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.textDarkSecondary,
                    ),
                  ),
                  Text(
                    widget.debt.remainingAmount.toRupiah,
                    style: AppTheme.monoCurrency(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                CurrencyInputFormatter(),
              ],
              style: AppTheme.monoCurrency(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Jumlah Pembayaran (Rp)',
                hintText: 'misal: 100.000',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final val = CurrencyInputFormatter.parse(v);
                if (val <= 0) return 'Nominal bayar harus > 0';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteCtrl,
              style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'misal: Cicilan ke-3',
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
            backgroundColor: AppTheme.success,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Bayar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyInputFormatter.parse(_amountCtrl.text);

    try {
      await ref.read(debtsProvider.notifier).recordPayment(
            debtId: widget.debt.id,
            amount: amount,
            paymentDate: _paymentDate,
            note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
          );

      // Auto sync to transactions: create an expense transaction under debt category
      try {
        final categories = ref.read(categoriesProvider).value ?? [];
        final debtCategory = categories.cast<Category?>().firstWhere(
          (c) =>
              c != null &&
              c.type == CategoryType.expense &&
              (c.name.toLowerCase().contains('utang') ||
                  c.name.toLowerCase().contains('cicilan') ||
                  c.name.toLowerCase().contains('pinjaman') ||
                  c.name.toLowerCase().contains('kpr') ||
                  c.name.toLowerCase().contains('paylater')),
          orElse: () => categories.cast<Category?>().firstWhere(
            (c) => c?.type == CategoryType.expense,
            orElse: () => categories.isNotEmpty ? categories.first : null,
          ),
        );

        if (debtCategory != null) {
          await ref.read(transactionsProvider.notifier).addTransaction(
                categoryId: debtCategory.id,
                type: TransactionType.expense,
                amount: amount,
                transactionDate: _paymentDate,
                description:
                    'Bayar Utang: ${widget.debt.name}${_noteCtrl.text.isNotEmpty ? " (${_noteCtrl.text})" : ""}',
                paymentMethod: 'Transfer Bank',
              );
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Pembayaran cicilan & transaksi pengeluaran berhasil dicatat!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal mencatat pembayaran cicilan. Silakan coba lagi.'),
        );
      }
    }
  }
}
