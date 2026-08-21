// lib/features/debts_savings/presentation/widgets/add_debt_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
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
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        'Tambah Catatan Utang / Cicilan',
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
                  labelText: 'Nama Tagihan / Pinjaman',
                  hintText: 'misal: SPayLater, KTA, Cicilan HP',
                ),
                validator: (v) => v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<DebtType>(
                isExpanded: true,
                initialValue: _debtType,
                decoration: const InputDecoration(labelText: 'Tipe Utang'),
                items: DebtType.values.map((t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(
                      t.displayName,
                      style: GoogleFonts.dmSans(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _debtType = val);
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _totalAmountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Total Pokok Pinjaman (Rp)',
                  hintText: 'misal: 32.000.000',
                  prefixText: 'Rp ',
                ),
                validator: (v) =>
                    CurrencyInputFormatter.parse(v) <= 0 ? 'Nominal > 0' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _remainingCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Sisa Utang Saat Ini (Rp)',
                  hintText: 'misal: 32.000.000',
                  prefixText: 'Rp ',
                  suffixIcon: Tooltip(
                    message: 'Bisa dikosongkan jika utang baru (otomatis sama dengan pokok pinjaman)',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textDarkMuted),
                  ),
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final rem = CurrencyInputFormatter.parse(v);
                    if (rem < 0) return 'Nominal >= 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _minPaymentCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                style: AppTheme.monoCurrency(fontSize: 15),
                decoration: const InputDecoration(
                  labelText: 'Estimasi Cicilan per Bulan (Rp)',
                  hintText: 'misal: 500.000 (opsional)',
                  prefixText: 'Rp ',
                  suffixIcon: Tooltip(
                    message: 'Opsional: estimasi cicilan bulanan untuk panduan anggaran',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textDarkMuted),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _dueDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tanggal Jatuh Tempo Bulanan',
                  hintText: 'misal: 25 (opsional)',
                  suffixIcon: Tooltip(
                    message: 'Opsional: tanggal jatuh tempo pembayaran setiap bulan (1-31)',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.textDarkMuted),
                  ),
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
            backgroundColor: AppTheme.warning,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final total = CurrencyInputFormatter.parse(_totalAmountCtrl.text);
    final rawRem = _remainingCtrl.text.trim();
    final remaining =
        rawRem.isEmpty ? total : CurrencyInputFormatter.parse(rawRem);
    final minPay = CurrencyInputFormatter.parse(_minPaymentCtrl.text);
    final dueDay = int.tryParse(_dueDayCtrl.text);
    final name = _nameCtrl.text.trim();

    try {
      await ref.read(debtsProvider.notifier).addDebt(
            name: name,
            debtType: _debtType,
            totalAmount: total,
            remainingAmount: remaining,
            minimumPayment: minPay,
            dueDay: dueDay,
          );

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          'Catatan utang "$name" berhasil dibuat!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}
