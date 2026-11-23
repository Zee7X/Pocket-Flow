// lib/features/transactions/presentation/widgets/add_transaction_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/extensions/currency_extension.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/utils/error_helper.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/ui.dart';
import '../../../categories_rules/domain/category.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../debts_savings/domain/savings_transaction.dart';
import '../../../debts_savings/presentation/providers/debts_savings_provider.dart';
import '../../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../../smart/presentation/providers/smart_providers.dart';
import '../../../wallets/domain/wallet.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/transaction.dart';
import '../providers/transactions_provider.dart';
import 'pickers.dart';

/// Buka form transaksi sebagai bottom sheet (HP) atau dialog (layar lebar).
Future<void> showAddTransaction(
  BuildContext context, {
  TransactionType type = TransactionType.expense,
  TransactionModel? initial,
  String? categoryId,
  int? amount,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => AddTransactionDialog(
      initialType: type,
      initialTransaction: initial,
      initialCategoryId: categoryId,
      initialAmount: amount,
    ),
  );
}

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
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descCtrl;
  final _newCatCtrl = TextEditingController();
  late TransactionType _type;
  String? _selectedCategoryId;
  bool _categoryTouched = false;
  String? _walletId;
  String? _toWalletId;
  String? _linkedDebtId;
  String? _linkedGoalId;
  late DateTime _transactionDate;
  bool _addingCategory = false;
  bool _showNoIncomeWarning = false;
  bool _saving = false;
  String? _amountError;

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initialTransaction;
    if (init != null) {
      _amountCtrl = TextEditingController(
        text: CurrencyInputFormatter.format(init.amount),
      );
      _descCtrl = TextEditingController(
        text: init.merchant ?? init.description ?? '',
      );
      _type = init.type;
      _selectedCategoryId = init.categoryId;
      _categoryTouched = true;
      _transactionDate = init.transactionDate;
      _walletId = init.walletId;
      _toWalletId = init.toWalletId;
    } else {
      _amountCtrl = TextEditingController(
        text: (widget.initialAmount ?? 0) > 0
            ? CurrencyInputFormatter.format(widget.initialAmount!)
            : '',
      );
      _descCtrl = TextEditingController();
      _type = widget.initialType;
      _selectedCategoryId = widget.initialCategoryId;
      _categoryTouched = widget.initialCategoryId != null;
      _transactionDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  bool get _isUpcoming {
    final now = DateTime.now();
    final d = DateTime(
      _transactionDate.year,
      _transactionDate.month,
      _transactionDate.day,
    );
    return d.isAfter(DateTime(now.year, now.month, now.day));
  }

  void _setType(TransactionType t) {
    if (t == _type) return;
    setState(() {
      _type = t;
      _selectedCategoryId = null;
      _categoryTouched = false;
      _linkedDebtId = null;
      _linkedGoalId = null;
      _showNoIncomeWarning = false;
    });
    _suggestCategory();
  }

  /// Saran kategori dari merchant/catatan (aturan yang dipelajari + kata kunci).
  void _suggestCategory() {
    if (_categoryTouched || _type == TransactionType.transfer) return;
    final s = ref
        .read(categorySuggesterProvider)
        .suggest(
          merchant: _descCtrl.text,
          isIncome: _type == TransactionType.income,
        );
    if (s != null && s.categoryId != _selectedCategoryId) {
      setState(() => _selectedCategoryId = s.categoryId);
    }
  }

  Future<void> _createCategory([String? preset]) async {
    final name = (preset ?? _newCatCtrl.text).trim();
    if (name.isEmpty) return;
    try {
      final c = await ref
          .read(categoriesProvider.notifier)
          .addCategory(
            name: name,
            type: _type == TransactionType.income
                ? CategoryType.income
                : CategoryType.expense,
            isFixed: false,
          );
      if (!mounted) return;
      setState(() {
        _selectedCategoryId = c.id;
        _categoryTouched = true;
        _addingCategory = false;
        _newCatCtrl.clear();
      });
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menambahkan kategori.',
          ),
        );
      }
    }
  }

  void _save({bool ignoreNoIncome = false}) {
    final amount = CurrencyInputFormatter.parse(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _amountError = 'Isi nominal');
      return;
    }
    if (_type == TransactionType.transfer &&
        (_walletId == null || _toWalletId == null)) {
      AppTheme.showErrorSnackBar(context, 'Pilih dompet asal dan tujuan.');
      return;
    }

    // Peringatan "belum ada pemasukan" hanya untuk pengeluaran nyata bulan ini.
    if (!ignoreNoIncome &&
        _type == TransactionType.expense &&
        !_isEditing &&
        !_isUpcoming) {
      final txList = ref.read(transactionsProvider).value ?? [];
      final budgets = ref.read(monthlyBudgetsProvider).value ?? [];
      final salary = ref.read(salaryHistoryProvider).value ?? [];
      final hasSalary = salary.any(
        (s) =>
            s.periodMonth == _transactionDate.month &&
            s.periodYear == _transactionDate.year,
      );
      final hasIncome = txList.any(
        (t) =>
            t.type == TransactionType.income &&
            t.transactionDate.month == _transactionDate.month &&
            t.transactionDate.year == _transactionDate.year,
      );
      if (budgets.isEmpty && !hasSalary && !hasIncome) {
        setState(() => _showNoIncomeWarning = true);
        return;
      }
    }
    _executeSave(amount);
  }

  String? _paymentMethodFor(String? walletId) {
    final w = (ref.read(walletsProvider).value ?? const <Wallet>[])
        .where((x) => x.id == walletId)
        .firstOrNull;
    return switch (w?.kind) {
      WalletKind.cash => 'Cash',
      WalletKind.bank => 'Transfer Bank',
      WalletKind.ewallet => 'E-Wallet',
      WalletKind.credit => 'Kartu Kredit',
      WalletKind.paylater => 'Paylater',
      _ => null,
    };
  }

  Future<void> _executeSave(int amount) async {
    setState(() => _saving = true);
    final desc = _descCtrl.text.trim();
    final note = desc.isEmpty ? null : desc;
    final categoryId = _type == TransactionType.transfer
        ? null
        : _selectedCategoryId;
    try {
      final n = ref.read(transactionsProvider.notifier);
      if (_isEditing) {
        await n.editTransaction(
          id: widget.initialTransaction!.id,
          categoryId: categoryId,
          type: _type,
          amount: amount,
          transactionDate: _transactionDate,
          description: note,
          merchant: note,
          paymentMethod: _paymentMethodFor(_walletId),
          walletId: _walletId,
          toWalletId: _toWalletId,
        );
      } else {
        await n.addTransaction(
          categoryId: categoryId,
          type: _type,
          amount: amount,
          transactionDate: _transactionDate,
          description: note,
          merchant: note,
          paymentMethod: _paymentMethodFor(_walletId),
          walletId: _walletId,
          toWalletId: _toWalletId,
        );
        if (_linkedDebtId != null) {
          try {
            await ref
                .read(debtsProvider.notifier)
                .recordPayment(
                  debtId: _linkedDebtId!,
                  amount: amount,
                  paymentDate: _transactionDate,
                  note: note ?? 'Dari Transaksi Pengeluaran',
                );
          } catch (_) {}
        }
        if (_linkedGoalId != null) {
          try {
            await ref
                .read(savingsGoalsProvider.notifier)
                .recordSavingsTransaction(
                  savingsGoalId: _linkedGoalId!,
                  type: SavingsTransactionType.deposit,
                  amount: amount,
                  transactionDate: _transactionDate,
                  note: note ?? 'Dari Transaksi Tabungan',
                );
          } catch (_) {}
        }
      }
      if (!mounted) return;
      Navigator.pop(context);
      AppTheme.showSuccessSnackBar(
        context,
        _isEditing
            ? 'Transaksi diperbarui.'
            : _linkedDebtId != null
            ? 'Transaksi dicatat dan sisa utang dikurangi.'
            : _linkedGoalId != null
            ? 'Transaksi dicatat dan masuk ke target tabungan.'
            : '${amount.toRupiah} dicatat.',
      );
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menyimpan transaksi. Silakan coba lagi.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final selectedCategory = categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    final activeDebts = (ref.watch(debtsProvider).value ?? [])
        .where((d) => !d.isPaid)
        .toList();
    final activeGoals = (ref.watch(savingsGoalsProvider).value ?? [])
        .where((g) => !g.isCompleted)
        .toList();
    final hasWallets =
        (ref.watch(walletsProvider).value ?? const []).isNotEmpty;

    final catName = selectedCategory?.name.toLowerCase() ?? '';
    final isDebtCategory =
        selectedCategory?.type == CategoryType.debt ||
        [
          'utang',
          'cicilan',
          'pinjaman',
          'kpr',
          'paylater',
        ].any(catName.contains);
    final isSavingCategory =
        selectedCategory?.type == CategoryType.savings ||
        ['tabung', 'darurat', 'invest', 'saving'].any(catName.contains);
    final hasIncomeCategories = categories.any(
      (c) => c.type == CategoryType.income,
    );
    final isTransfer = _type == TransactionType.transfer;

    return AppModalScaffold(
      title: _isEditing ? 'Edit Transaksi' : 'Catat Transaksi',
      actions: [
        AppModalScaffold.cancelButton(context),
        ElevatedButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Simpan Edit' : 'Simpan'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<TransactionType>(
            items: [
              (TransactionType.expense, 'Pengeluaran'),
              (TransactionType.income, 'Pemasukan'),
              if (hasWallets || _type == TransactionType.transfer)
                (TransactionType.transfer, 'Transfer'),
            ],
            value: _type,
            onChanged: _setType,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 24, weight: FontWeight.w700),
            onChanged: (_) => _amountError == null
                ? null
                : setState(() => _amountError = null),
            decoration: InputDecoration(
              labelText: 'Nominal',
              hintText: '0',
              prefixText: 'Rp ',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _suggestCategory(),
            decoration: InputDecoration(
              labelText: isTransfer ? 'Keterangan' : 'Untuk apa',
              hintText: isTransfer
                  ? 'mis. Top up GoPay'
                  : 'mis. Makan siang geprek',
            ),
          ),

          if (!isTransfer) ...[
            const SizedBox(height: 18),
            AppFieldLabel(
              'Kategori',
              trailing: _addingCategory
                  ? null
                  : InkWell(
                      onTap: () => setState(() => _addingCategory = true),
                      child: Text(
                        '+ Kategori baru',
                        style: Ui.body(
                          size: 12.5,
                          color: AppTheme.primary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            if (_addingCategory)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCatCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _createCategory(),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: _type == TransactionType.income
                              ? 'mis. Freelance'
                              : 'mis. Transport',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _addingCategory = false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => _createCategory(),
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
              ),
            if (_type == TransactionType.income && !hasIncomeCategories)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in const [
                    'Gaji Utama',
                    'Bonus & THR',
                    'Freelance',
                    'Investasi',
                    'Pemasukan Lainnya',
                  ])
                    ActionChip(
                      label: Text('+ $p'),
                      onPressed: () => _createCategory(p),
                    ),
                ],
              )
            else
              CategoryPicker(
                type: _type,
                value: _selectedCategoryId,
                onChanged: (v) => setState(() {
                  _selectedCategoryId = v;
                  _categoryTouched = true;
                  _linkedDebtId = null;
                  _linkedGoalId = null;
                }),
              ),
          ],

          if (_type == TransactionType.expense &&
              activeDebts.isNotEmpty &&
              isDebtCategory) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Potong sisa utang (opsional)'),
            ChoiceChips<String>(
              values: [for (final d in activeDebts) d.id],
              selected: _linkedDebtId,
              label: (id) {
                final d = activeDebts.firstWhere((x) => x.id == id);
                return '${d.name} · sisa ${d.remainingAmount.toRupiahCompact}';
              },
              onChanged: (v) => setState(() => _linkedDebtId = v),
            ),
          ],

          if (_type == TransactionType.expense &&
              activeGoals.isNotEmpty &&
              isSavingCategory) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Setor ke target tabungan (opsional)'),
            ChoiceChips<String>(
              values: [for (final g in activeGoals) g.id],
              selected: _linkedGoalId,
              label: (id) => activeGoals.firstWhere((x) => x.id == id).name,
              onChanged: (v) => setState(() => _linkedGoalId = v),
            ),
          ],

          const SizedBox(height: 18),
          AppFieldLabel(
            isTransfer
                ? 'Dari dompet'
                : (_type == TransactionType.income
                      ? 'Masuk ke dompet'
                      : 'Dibayar dari'),
          ),
          WalletPicker(
            value: _walletId,
            onChanged: (v) => setState(() => _walletId = v),
          ),
          if (isTransfer) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Ke dompet'),
            WalletPicker(
              value: _toWalletId,
              excludeId: _walletId,
              onChanged: (v) => setState(() => _toWalletId = v),
            ),
          ],

          const SizedBox(height: 18),
          const AppFieldLabel('Tanggal'),
          DateField(
            value: _transactionDate,
            onChanged: (d) => setState(() => _transactionDate = d),
          ),
          if (_isUpcoming) ...[
            const SizedBox(height: 8),
            Text(
              'Transaksi terjadwal: belum mengurangi saldo sampai tanggalnya tiba.',
              style: Ui.body(size: 12.5, color: AppTheme.warning),
            ),
          ],

          if (_showNoIncomeWarning) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8EB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF5D9A8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Belum ada pemasukan bulan ini',
                    style: Ui.title(size: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catat gaji atau pemasukan dulu supaya pengeluaran bisa dibandingkan dengan budget.',
                    style: Ui.body(size: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _save(ignoreNoIncome: true),
                          child: const Text('Tetap simpan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _setType(TransactionType.income),
                          child: const Text('Ubah ke pemasukan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
