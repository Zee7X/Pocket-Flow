// lib/features/transactions/presentation/widgets/add_transaction_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../categories_rules/domain/category.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../debts_savings/domain/savings_transaction.dart';
import '../../../debts_savings/presentation/providers/debts_savings_provider.dart';
import '../../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../domain/transaction.dart';
import '../providers/transactions_provider.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final TransactionModel? initialTransaction;
  final String? initialCategoryId;
  final int? initialAmount;

  const AddTransactionDialog({
    super.key,
    this.initialType = TransactionType.expense,
    this.initialTransaction,
    this.initialCategoryId,
    this.initialAmount,
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
  String? _linkedDebtId;
  String? _linkedGoalId;
  late DateTime _transactionDate;
  late String _paymentMethod;

  final _paymentMethods = ['Cash', 'Transfer Bank', 'QRIS', 'E-Wallet', 'Debit'];

  @override
  void initState() {
    super.initState();
    final init = widget.initialTransaction;
    if (init != null) {
      _amountCtrl = TextEditingController(
        text: CurrencyInputFormatter.format(init.amount),
      );
      _descCtrl = TextEditingController(text: init.description ?? '');
      _type = init.type;
      _selectedCategoryId = init.categoryId;
      _transactionDate = init.transactionDate;
      _paymentMethod = init.paymentMethod ?? 'Cash';
    } else {
      _amountCtrl = TextEditingController(
        text: (widget.initialAmount != null && widget.initialAmount! > 0)
            ? CurrencyInputFormatter.format(widget.initialAmount!)
            : '',
      );
      _descCtrl = TextEditingController();
      _type = widget.initialType;
      _selectedCategoryId = widget.initialCategoryId;
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

    final debtsAsync = ref.watch(debtsProvider);
    final activeDebts =
        (debtsAsync.value ?? []).where((d) => !d.isPaid).toList();

    final goalsAsync = ref.watch(savingsGoalsProvider);
    final activeGoals =
        (goalsAsync.value ?? []).where((g) => !g.isCompleted).toList();

    final selectedCategory = categories.cast<Category?>().firstWhere(
          (c) => c?.id == _selectedCategoryId,
          orElse: () => null,
        );

    final isDebtCategory = selectedCategory != null &&
        (selectedCategory.name.toLowerCase().contains('utang') ||
            selectedCategory.name.toLowerCase().contains('cicilan') ||
            selectedCategory.name.toLowerCase().contains('pinjaman') ||
            selectedCategory.name.toLowerCase().contains('kpr') ||
            selectedCategory.name.toLowerCase().contains('paylater'));

    final isSavingCategory = selectedCategory != null &&
        (selectedCategory.name.toLowerCase().contains('tabung') ||
            selectedCategory.name.toLowerCase().contains('darurat') ||
            selectedCategory.name.toLowerCase().contains('invest') ||
            selectedCategory.name.toLowerCase().contains('saving'));

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                      if (v) {
                        setState(() {
                          _type = TransactionType.expense;
                          _selectedCategoryId = null;
                        });
                      }
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
                      if (v) {
                        setState(() {
                          _type = TransactionType.income;
                          _selectedCategoryId = null;
                          _linkedDebtId = null;
                          _linkedGoalId = null;
                        });
                      }
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
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              style: AppTheme.monoCurrency(fontSize: 18),
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                hintText: '50.000',
                prefixText: 'Rp ',
              ),
              validator: (v) {
                final val = CurrencyInputFormatter.parse(v);
                if (val <= 0) return 'Nominal harus > 0';
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
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                  _linkedDebtId = null;
                  _linkedGoalId = null;
                });
              },
            ),
            const SizedBox(height: 14),

            // Optional Linked Debt Dropdown
            if (_type == TransactionType.expense &&
                activeDebts.isNotEmpty &&
                (isDebtCategory || _linkedDebtId != null)) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _linkedDebtId,
                decoration: const InputDecoration(
                  labelText: 'Potong Catatan Pinjaman',
                  suffixIcon: Tooltip(
                    message:
                        'Jika dipilih, sisa pokok pinjaman tersebut akan otomatis berkurang.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded,
                        size: 18, color: AppTheme.textDarkMuted),
                  ),
                ),
                hint: Text(
                  'Pilih Utang (opsional)',
                  style: GoogleFonts.dmSans(color: AppTheme.textDarkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Jangan hubungkan ke utang tertentu'),
                  ),
                  ...activeDebts.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(
                          '${d.name} (Sisa: ${d.remainingAmount.toRupiah})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (val) => setState(() => _linkedDebtId = val),
              ),
              const SizedBox(height: 14),
            ],

            // Optional Linked Savings Goal Dropdown
            if (_type == TransactionType.expense &&
                activeGoals.isNotEmpty &&
                (isSavingCategory || _linkedGoalId != null)) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _linkedGoalId,
                decoration: const InputDecoration(
                  labelText: 'Setor ke Target Tabungan',
                  suffixIcon: Tooltip(
                    message:
                        'Jika dipilih, saldo terkumpul pada target tersebut akan otomatis bertambah.',
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.help_outline_rounded,
                        size: 18, color: AppTheme.textDarkMuted),
                  ),
                ),
                hint: Text(
                  'Pilih Target (opsional)',
                  style: GoogleFonts.dmSans(color: AppTheme.textDarkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Jangan hubungkan ke target tertentu'),
                  ),
                  ...activeGoals.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(
                          '${g.name} (Terkumpul: ${g.currentAmount.toRupiah})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: (val) => setState(() => _linkedGoalId = val),
              ),
              const SizedBox(height: 14),
            ],

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

    final amount = CurrencyInputFormatter.parse(_amountCtrl.text);
    final isEditing = widget.initialTransaction != null;

    if (_type == TransactionType.expense && !isEditing) {
      final txList = ref.read(transactionsProvider).value ?? [];
      final budgetsList = ref.read(monthlyBudgetsProvider).value ?? [];
      final salaryHistory = ref.read(salaryHistoryProvider).value ?? [];

      final hasSalaryBudget = budgetsList.isNotEmpty;
      final hasSalaryEntry = salaryHistory.any((s) =>
          s.periodMonth == _transactionDate.month &&
          s.periodYear == _transactionDate.year);

      final hasIncome = txList.any((t) =>
          t.type == TransactionType.income &&
          t.transactionDate.month == _transactionDate.month &&
          t.transactionDate.year == _transactionDate.year);

      if (!hasSalaryBudget && !hasSalaryEntry && !hasIncome) {
        _showNoIncomeWarning(context, amount);
        return;
      }
    }

    _executeSave(amount, isEditing: isEditing);
  }

  Future<void> _executeSave(int amount, {required bool isEditing}) async {
    try {
      if (isEditing) {
        await ref.read(transactionsProvider.notifier).editTransaction(
              id: widget.initialTransaction!.id,
              categoryId: _selectedCategoryId,
              type: _type,
              amount: amount,
              transactionDate: _transactionDate,
              description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
              paymentMethod: _paymentMethod,
            );
      } else {
        await ref.read(transactionsProvider.notifier).addTransaction(
              categoryId: _selectedCategoryId,
              type: _type,
              amount: amount,
              transactionDate: _transactionDate,
              description: _descCtrl.text.isNotEmpty ? _descCtrl.text : null,
              paymentMethod: _paymentMethod,
            );

        // Bi-directional sync: trigger payment on linked debt
        if (_linkedDebtId != null) {
          try {
            await ref.read(debtsProvider.notifier).recordPayment(
                  debtId: _linkedDebtId!,
                  amount: amount,
                  paymentDate: _transactionDate,
                  note: _descCtrl.text.isNotEmpty
                      ? _descCtrl.text
                      : 'Dari Transaksi Pengeluaran',
                );
          } catch (_) {}
        }

        // Bi-directional sync: trigger deposit on linked savings goal
        if (_linkedGoalId != null) {
          try {
            await ref.read(savingsGoalsProvider.notifier).recordSavingsTransaction(
                  savingsGoalId: _linkedGoalId!,
                  type: SavingsTransactionType.deposit,
                  amount: amount,
                  transactionDate: _transactionDate,
                  note: _descCtrl.text.isNotEmpty
                      ? _descCtrl.text
                      : 'Dari Transaksi Tabungan',
                );
          } catch (_) {}
        }
      }

      if (mounted) {
        Navigator.pop(context);
        AppTheme.showSuccessSnackBar(
          context,
          isEditing
              ? 'Transaksi berhasil diperbarui!'
              : (_linkedDebtId != null
                  ? 'Transaksi & pemotongan utang berhasil dicatat!'
                  : (_linkedGoalId != null
                      ? 'Transaksi & setoran tabungan berhasil dicatat!'
                      : 'Transaksi berhasil dicatat!')),
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
