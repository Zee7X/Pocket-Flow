// lib/features/transactions/presentation/widgets/add_transaction_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../domain/transaction.dart';
import '../providers/transactions_provider.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  final TransactionType initialType;

  const AddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
  });

  @override
  ConsumerState<AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late TransactionType _type;
  String? _selectedCategoryId;
  DateTime _transactionDate = DateTime.now();
  String _paymentMethod = 'Cash';

  final _paymentMethods = ['Cash', 'Transfer Bank', 'QRIS', 'E-Wallet', 'Debit'];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];
    final filteredCategories =
        categories.where((c) => c.type.toDbString() == _type.toDbString()).toList();

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      title: Text(
        'Catat Transaksi',
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
              // Type Segmented Switch
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text('Pengeluaran', style: GoogleFonts.dmSans())),
                      selected: _type == TransactionType.expense,
                      selectedColor: AppTheme.danger.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: _type == TransactionType.expense
                            ? AppTheme.danger
                            : AppTheme.textDarkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (v) {
                        if (v) setState(() => _type = TransactionType.expense);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text('Pemasukan', style: GoogleFonts.dmSans())),
                      selected: _type == TransactionType.income,
                      selectedColor: AppTheme.success.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        color: _type == TransactionType.income
                            ? AppTheme.success
                            : AppTheme.textDarkMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (v) {
                        if (v) setState(() => _type = TransactionType.income);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: AppTheme.monoCurrency(fontSize: 18),
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: '50000',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final clean = v?.replaceAll('.', '').replaceAll(',', '') ?? '';
                  final val = int.tryParse(clean);
                  if (val == null || val <= 0) return 'Nominal harus > 0';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Kategori'),
                hint: const Text('Pilih Kategori (opsional)'),
                items: filteredCategories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, style: GoogleFonts.dmSans()),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descCtrl,
                style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
                decoration: const InputDecoration(
                  labelText: 'Keterangan (Catatan)',
                  hintText: 'misal: Makan siang geprek',
                ),
              ),
              const SizedBox(height: 14),

              // Payment method & Date
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paymentMethod,
                      decoration: const InputDecoration(labelText: 'Metode'),
                      items: _paymentMethods.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m));
                      }).toList(),
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        DateFormat('dd/MM').format(_transactionDate),
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: const BorderSide(color: AppTheme.borderDark),
                        foregroundColor: AppTheme.textDarkPrimary,
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
            backgroundColor: _type == TransactionType.expense
                ? AppTheme.danger
                : AppTheme.success,
            minimumSize: const Size(100, 42),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _transactionDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));

    ref.read(transactionsProvider.notifier).addTransaction(
          categoryId: _selectedCategoryId,
          type: _type,
          amount: amount,
          transactionDate: _transactionDate,
          description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
          paymentMethod: _paymentMethod,
        );

    Navigator.pop(context);
  }
}
