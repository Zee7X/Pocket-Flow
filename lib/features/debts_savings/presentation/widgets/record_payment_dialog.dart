// lib/features/debts_savings/presentation/widgets/record_payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
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
      _amountCtrl.text = widget.debt.minimumPayment.toString();
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
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      title: Text(
        'Bayar Cicilan: ${widget.debt.name}',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
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
              'Sisa utang saat ini: ${widget.debt.remainingAmount.toRupiah}',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textDarkSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: AppTheme.monoCurrency(fontSize: 16),
              decoration: const InputDecoration(
                labelText: 'Jumlah Pembayaran (Rp)',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final clean = v?.replaceAll('.', '') ?? '';
                final val = int.tryParse(clean);
                if (val == null || val <= 0) return 'Nominal bayar harus > 0';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountCtrl.text.replaceAll('.', ''));

    ref.read(debtsProvider.notifier).recordPayment(
          debtId: widget.debt.id,
          amount: amount,
          paymentDate: _paymentDate,
          note: _noteCtrl.text.isNotEmpty ? _noteCtrl.text : null,
        );

    Navigator.pop(context);
  }
}
