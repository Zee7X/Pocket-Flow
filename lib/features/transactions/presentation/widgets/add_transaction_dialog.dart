// lib/features/transactions/presentation/widgets/add_transaction_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/utils/error_helper.dart';
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
      actionsOverflowButtonSpacing: 8,
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            // Type Segmented Toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLightAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = TransactionType.expense;
                          _selectedCategoryId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.expense
                              ? AppTheme.danger.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: _type == TransactionType.expense
                              ? Border.all(color: AppTheme.danger.withValues(alpha: 0.3))
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pengeluaran',
                          style: GoogleFonts.dmSans(
                            color: _type == TransactionType.expense
                                ? AppTheme.danger
                                : AppTheme.textDarkSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _type = TransactionType.income;
                          _selectedCategoryId = null;
                          _linkedDebtId = null;
                          _linkedGoalId = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _type == TransactionType.income
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: _type == TransactionType.income
                              ? Border.all(color: AppTheme.success.withValues(alpha: 0.3))
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Pemasukan',
                          style: GoogleFonts.dmSans(
                            color: _type == TransactionType.income
                                ? AppTheme.success
                                : AppTheme.textDarkSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

            // Category label & Quick add button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Kategori',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkSecondary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _quickAddCategory(),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            size: 15, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Kategori Baru',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Category dropdown
            AppDropdownFormField<String>(
              value: _selectedCategoryId,
              hintText: 'Pilih Kategori (opsional)',
              prefixIcon: Icon(
                _type == TransactionType.income
                    ? Icons.savings_outlined
                    : Icons.category_outlined,
                size: 20,
                color: _type == TransactionType.income
                    ? AppTheme.success
                    : AppTheme.primary,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: AppDropdownItemContent(
                    icon: Icons.label_off_outlined,
                    iconColor: AppTheme.textDarkMuted,
                    iconBgColor: AppTheme.surfaceLightAlt,
                    title: 'Tanpa Kategori (Umum)',
                  ),
                ),
                ...filteredCategories.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: AppDropdownItemContent(
                      icon: c.isFixed
                          ? Icons.push_pin_rounded
                          : (_type == TransactionType.income
                              ? Icons.account_balance_wallet_outlined
                              : Icons.folder_outlined),
                      iconColor: _type == TransactionType.income
                          ? AppTheme.success
                          : (c.isFixed ? AppTheme.warning : AppTheme.primary),
                      iconBgColor: _type == TransactionType.income
                          ? AppTheme.pastelGreen
                          : (c.isFixed
                              ? AppTheme.pastelYellow
                              : AppTheme.pastelBlue),
                      title: c.name,
                      badgeText: _type == TransactionType.income
                          ? 'Pemasukan'
                          : (c.isFixed ? 'Tetap' : 'Variabel'),
                      badgeColor: _type == TransactionType.income
                          ? AppTheme.success
                          : (c.isFixed ? AppTheme.warning : AppTheme.primary),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                  _linkedDebtId = null;
                  _linkedGoalId = null;
                });
              },
            ),

            // Quick Preset Chips for Income if none exist yet
            if (_type == TransactionType.income && filteredCategories.isEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.pastelGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 14, color: AppTheme.success),
                        const SizedBox(width: 6),
                        Text(
                          'Pilih Cepat Kategori Pemasukan:',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDarkPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        'Gaji Utama',
                        'Bonus & THR',
                        'Freelance',
                        'Investasi',
                        'Pemasukan Lainnya',
                      ].map((preset) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.borderLight),
                          label: Text(
                            '+ $preset',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.success,
                            ),
                          ),
                          onPressed: () => _quickAddCategory(preset),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Optional Linked Debt Dropdown
            if (_type == TransactionType.expense &&
                activeDebts.isNotEmpty &&
                (isDebtCategory || _linkedDebtId != null)) ...[
              AppDropdownFormField<String>(
                value: _linkedDebtId,
                labelText: 'Potong Catatan Pinjaman',
                hintText: 'Pilih Utang (opsional)',
                prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20, color: AppTheme.danger),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: AppDropdownItemContent(
                      icon: Icons.do_not_disturb_on_outlined,
                      iconColor: AppTheme.textDarkMuted,
                      iconBgColor: AppTheme.surfaceLightAlt,
                      title: 'Jangan hubungkan ke utang tertentu',
                    ),
                  ),
                  ...activeDebts.map((d) => DropdownMenuItem(
                        value: d.id,
                        child: AppDropdownItemContent(
                          icon: Icons.credit_card_off_rounded,
                          iconColor: AppTheme.danger,
                          iconBgColor: AppTheme.pastelRed,
                          title: d.name,
                          subtitle: 'Sisa utang: ${d.remainingAmount.toRupiah}',
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
              AppDropdownFormField<String>(
                value: _linkedGoalId,
                labelText: 'Setor ke Target Tabungan',
                hintText: 'Pilih Target (opsional)',
                prefixIcon: const Icon(Icons.savings_outlined, size: 20, color: AppTheme.success),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: AppDropdownItemContent(
                      icon: Icons.do_not_disturb_on_outlined,
                      iconColor: AppTheme.textDarkMuted,
                      iconBgColor: AppTheme.surfaceLightAlt,
                      title: 'Jangan hubungkan ke target tertentu',
                    ),
                  ),
                  ...activeGoals.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: AppDropdownItemContent(
                          icon: Icons.savings_rounded,
                          iconColor: AppTheme.success,
                          iconBgColor: AppTheme.pastelGreen,
                          title: g.name,
                          subtitle: 'Terkumpul: ${g.currentAmount.toRupiah}',
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

            // Payment method
            AppDropdownFormField<String>(
              value: _paymentMethod,
              labelText: 'Metode Pembayaran',
              items: _paymentMethods.map((m) {
                final IconData mIcon = switch (m) {
                  'Transfer Bank' => Icons.account_balance_rounded,
                  'Tunai' => Icons.payments_outlined,
                  'QRIS' => Icons.qr_code_2_rounded,
                  'Kartu Debit' => Icons.credit_card_rounded,
                  'Kartu Kredit' => Icons.credit_card_rounded,
                  'E-Wallet' => Icons.account_balance_wallet_rounded,
                  _ => Icons.payment_rounded,
                };
                return DropdownMenuItem(
                  value: m,
                  child: AppDropdownItemContent(
                    icon: mIcon,
                    iconColor: AppTheme.primary,
                    iconBgColor: AppTheme.pastelBlue,
                    title: m,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _paymentMethod = val!),
            ),
            const SizedBox(height: 14),

            // Date Button
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: _isUpcoming ? AppTheme.warning : AppTheme.primary,
              ),
              label: Text(
                'Tanggal: ${DateFormat('dd MMMM yyyy').format(_transactionDate)}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                side: BorderSide(
                  color: _isUpcoming
                      ? AppTheme.warning
                      : AppTheme.borderLight,
                ),
                foregroundColor: AppTheme.textDarkPrimary,
              ),
            ),
            // Scheduled (future-dated) transaction hint
            if (_isUpcoming) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.pastelAmber.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Transaksi terjadwal — akan tercatat di bulan ${_monthYearLabel(_transactionDate)}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDarkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          ),
          child: Text(isEditing ? 'Simpan Edit' : 'Simpan'),
        ),
      ],
    );
  }

  Future<void> _quickAddCategory([String? presetName]) async {
    final nameCtrl = TextEditingController(text: presetName ?? '');
    final isSaved = presetName != null
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              title: Text(
                _type == TransactionType.income
                    ? 'Tambah Kategori Pemasukan'
                    : 'Tambah Kategori Pengeluaran',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
              content: TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama Kategori',
                  hintText: _type == TransactionType.income
                      ? 'misal: Gaji Pokok, Bonus, Freelance'
                      : 'misal: Makan, Transport, Pulsa',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Simpan'),
                ),
              ],
            ),
          );

    if (isSaved == true && nameCtrl.text.trim().isNotEmpty) {
      final name = nameCtrl.text.trim();
      try {
        final newCat = await ref.read(categoriesProvider.notifier).addCategory(
              name: name,
              type: _type == TransactionType.income
                  ? CategoryType.income
                  : CategoryType.expense,
              isFixed: false,
            );
        if (!mounted) {
          nameCtrl.dispose();
          return;
        }
        setState(() {
          _selectedCategoryId = newCat.id;
        });
        AppTheme.showSuccessSnackBar(
          context,
          'Kategori "$name" berhasil dipilih!',
        );
      } catch (e) {
        if (!mounted) {
          nameCtrl.dispose();
          return;
        }
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menambahkan kategori.'),
        );
      }
    }
    nameCtrl.dispose();
  }

  bool get _isUpcoming {
    final now = DateTime.now();
    final txDate = DateTime(_transactionDate.year, _transactionDate.month, _transactionDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return txDate.isAfter(today);
  }

  static const _monthNames = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _monthYearLabel(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    // Scheduled transactions allowed up to 12 months ahead.
    final lastDate = DateTime(now.year, now.month + 12, now.day);
    final picked = await showDatePicker(
      context: context,
      // Clamp legacy out-of-range entries (e.g. 2035) so the picker doesn't crash.
      initialDate: _transactionDate.isAfter(lastDate)
          ? lastDate
          : _transactionDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );
    if (picked != null) setState(() => _transactionDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyInputFormatter.parse(_amountCtrl.text);
    final isEditing = widget.initialTransaction != null;

    // The no-income warning only guards actual spending; a future-dated
    // expense is a plan and that month's income may not be recorded yet.
    if (_type == TransactionType.expense && !isEditing && !_isUpcoming) {
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
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menyimpan transaksi. Silakan coba lagi.'),
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
