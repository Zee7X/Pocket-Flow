// lib/features/debts_savings/presentation/widgets/add_debt_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../domain/debt.dart';
import '../providers/debts_savings_provider.dart';

class AddDebtDialog extends ConsumerStatefulWidget {
  const AddDebtDialog({super.key});

  @override
  ConsumerState<AddDebtDialog> createState() => _AddDebtDialogState();
}

class _AddDebtDialogState extends ConsumerState<AddDebtDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();
  final _minPaymentCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController();
  DebtType _debtType = DebtType.paylater;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _totalAmountCtrl.dispose();
    _remainingCtrl.dispose();
    _minPaymentCtrl.dispose();
    _dueDayCtrl.dispose();
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
        'Tambah Catatan Utang / Cicilan',
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
                  labelText: 'Nama Utang / Layanan',
                  hintText: 'misal: SPayLater, Kredivo, KPR',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<DebtType>(
                initialValue: _debtType,
                decoration: const InputDecoration(labelText: 'Tipe'),
                items: DebtType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _debtType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _totalAmountCtrl,
                keyboardType: TextInputType.number,
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Total Pokok Pinjaman (Rp)',
                  hintText: '1000000',
                  prefixText: 'Rp ',
                ),
                onChanged: (v) {
                  if (_remainingCtrl.text.isEmpty) {
                    _remainingCtrl.text = v;
                  }
                },
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Nominal > 0' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _remainingCtrl,
                keyboardType: TextInputType.number,
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Sisa Utang Saat Ini (Rp)',
                  hintText: '1000000',
                  prefixText: 'Rp ',
                ),
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 0 ? 'Nominal >= 0' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minPaymentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cicilan/Bln',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _dueDayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jatuh Tempo Tgl',
                        hintText: '1-31',
                      ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final total = int.parse(_totalAmountCtrl.text.replaceAll('.', ''));
    final remaining = int.parse(_remainingCtrl.text.replaceAll('.', ''));
    final minPay = int.tryParse(_minPaymentCtrl.text.replaceAll('.', '')) ?? 0;
    final dueDay = int.tryParse(_dueDayCtrl.text);

    ref.read(debtsProvider.notifier).addDebt(
          name: _nameCtrl.text.trim(),
          debtType: _debtType,
          totalAmount: total,
          remainingAmount: remaining,
          minimumPayment: minPay,
          dueDay: dueDay,
        );

    Navigator.pop(context);
  }
}
