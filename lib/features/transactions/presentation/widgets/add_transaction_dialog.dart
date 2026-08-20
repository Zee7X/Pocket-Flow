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
  final TransactionModel? initialTransaction;

  const AddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialTransaction,
  });

  @override
  ConsumerState<AddTransactionDialog> createState() =>
      _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  late TransactionType _type;
  String? _selectedCategoryId;
  late DateTime _transactionDate;
  late String _paymentMethod;

  final _paymentMethods = ['Cash', 'Transfer Bank', 'QRIS', 'E-Wallet', 'Debit'];

  @override
  void initState() {
    super.initState();
    final init = widget.initialTransaction;
    if (init != null) {
      _amountCtrl = TextEditingController(text: init.amount.toString());
      _descCtrl = TextEditingController(text: init.description ?? '');
      _type = init.type;
      _selectedCategoryId = init.categoryId;
      _transactionDate = init.transactionDate;
      _paymentMethod = init.paymentMethod ?? 'Cash';
    } else {
      _amountCtrl = TextEditingController();
      _descCtrl = TextEditingController();
      _type = widget.initialType;
      _transactionDate = DateTime.now();
      _paymentMethod = 'Cash';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTransaction != null;
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? [];
    final filteredCategories =
        categories.where((c) => c.type.toDbString() == _type.toDbString()).toList();

    return AlertDialog(
      scrollable: true,
      backgroundColor: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        side: const BorderSide(color: AppTheme.borderLightSubtle),
      ),
      title: Text(
        isEditing ? 'Edit Transaksi' : 'Catat Transaksi',
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
            // Type Segmented Switch
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Pengeluaran', style: GoogleFonts.dmSans()),
                      ),
                    ),
                    selected: _type == TransactionType.expense,
                    selectedColor: AppTheme.danger.withValues(alpha: 0.15),
                    backgroundColor: AppTheme.surfaceLightAlt,
                    labelStyle: TextStyle(
                      color: _type == TransactionType.expense
                          ? AppTheme.danger
                          : AppTheme.textDarkSecondary,
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
                    showCheckmark: false,
                    label: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Pemasukan', style: GoogleFonts.dmSans()),
                      ),
                    ),
                    selected: _type == TransactionType.income,
                    selectedColor: AppTheme.success.withValues(alpha: 0.15),
                    backgroundColor: AppTheme.surfaceLightAlt,
                    labelStyle: TextStyle(
                      color: _type == TransactionType.income
                          ? AppTheme.success
                          : AppTheme.textDarkSecondary,
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
              isExpanded: true,
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Kategori'),
              hint: Text(
                'Pilih Kategori (opsional)',
                style: GoogleFonts.dmSans(color: AppTheme.textDarkMuted),
                overflow: TextOverflow.ellipsis,
              ),
              items: filteredCategories.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    c.name,
                    style: GoogleFonts.dmSans(),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _paymentMethod,
                    decoration: const InputDecoration(labelText: 'Metode'),
                    items: _paymentMethods.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          style: GoogleFonts.dmSans(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _paymentMethod = val!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat('dd/MM').format(_transactionDate),
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(double.infinity, 44),
                      side: const BorderSide(color: AppTheme.borderLight),
                      foregroundColor: AppTheme.textDarkPrimary,
                    ),
                  ),
                ),
              ],
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
            backgroundColor: _type == TransactionType.expense
                ? AppTheme.danger
                : AppTheme.success,
            minimumSize: const Size(100, 42),
          ),
          child: Text(isEditing ? 'Simpan Edit' : 'Simpan'),
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

    final amount =
        int.parse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    final isEditing = widget.initialTransaction != null;

    if (_type == TransactionType.expense && !isEditing) {
      final txList = ref.read(transactionsProvider).value ?? [];
      final hasIncome = txList.any((t) =>
          t.type == TransactionType.income &&
          t.transactionDate.month == _transactionDate.month &&
          t.transactionDate.year == _transactionDate.year);

      if (!hasIncome) {
        _showNoIncomeWarning(context, amount);
        return;
      }
    }

    _executeSave(amount, isEditing: isEditing);
  }

  void _executeSave(int amount, {required bool isEditing}) {
    if (isEditing) {
      ref.read(transactionsProvider.notifier).editTransaction(
            id: widget.initialTransaction!.id,
            categoryId: _selectedCategoryId,
            type: _type,
            amount: amount,
            transactionDate: _transactionDate,
            description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
            paymentMethod: _paymentMethod,
          );
    } else {
      ref.read(transactionsProvider.notifier).addTransaction(
            categoryId: _selectedCategoryId,
            type: _type,
            amount: amount,
            transactionDate: _transactionDate,
            description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
            paymentMethod: _paymentMethod,
          );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showNoIncomeWarning(BuildContext context, int amount) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          side: const BorderSide(color: AppTheme.borderLightSubtle),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7), // soft amber
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.warning,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum Ada Pemasukan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kamu belum mencatat pemasukan atau alokasi gaji di bulan ini. Agar pengeluaranmu dapat dipantau dan dialokasikan ke budget dengan tepat, sebaiknya catat pemasukan terlebih dahulu.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textDarkSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeSave(amount, isEditing: false);
            },
            child: Text(
              'Tetap Catat Pengeluaran',
              style: GoogleFonts.dmSans(
                color: AppTheme.textDarkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _type = TransactionType.income);
            },
            icon: const Icon(Icons.arrow_downward_rounded, size: 16),
            label: const Text('Catat Sebagai Pemasukan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
