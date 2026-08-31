// lib/features/transactions/presentation/transactions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/utils/error_helper.dart';
import '../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../domain/transaction.dart';
import 'providers/transactions_provider.dart';
import 'widgets/add_transaction_dialog.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String _filter = 'all'; // all, expense, income

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final period = ref.watch(selectedPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Riwayat Transaksi',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.date_range_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Ganti Periode',
            onPressed: () => _changePeriod(context, period),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.pastelBlue,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Tambah Transaksi',
            onPressed: () => _openAddTransaction(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter Chips ─────────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Semua', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pengeluaran', 'expense'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pemasukan', 'income'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Akan Datang', 'upcoming'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Transactions List ─────────────────────────────────────────
              Expanded(
                child: transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppErrorWidget(
                    error: e,
                    onRetry: () async {
                      ref.invalidate(transactionsProvider);
                    },
                  ),
                  data: (transactions) {
                    final filtered = transactions.where((t) {
                      if (_filter == 'expense') {
                        return t.type == TransactionType.expense;
                      }
                      if (_filter == 'income') {
                        return t.type == TransactionType.income;
                      }
                      if (_filter == 'upcoming') {
                        return t.isUpcoming;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum Ada Transaksi',
                        description:
                            'Catat pengeluaran harian atau pemasukan untuk mulai tracking keuanganmu.',
                        actionLabel: 'Catat Transaksi',
                        onAction: () => _openAddTransaction(context),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final tx = filtered[i];
                        final isExpense = tx.type == TransactionType.expense;
                        final isSavings = tx.isSavings;
                        final isDebt = tx.isDebt;
                        final isUpcoming = tx.isUpcoming;

                        final Color iconColor = isSavings
                            ? AppTheme.primary
                            : (isDebt
                                ? AppTheme.warning
                                : (isExpense ? AppTheme.danger : AppTheme.success));
                        final Color iconBg = isSavings
                            ? AppTheme.pastelBlue
                            : (isDebt
                                ? AppTheme.pastelAmber
                                : (isExpense ? AppTheme.pastelRed : AppTheme.pastelGreen));
                        final IconData icon = isSavings
                            ? Icons.savings_outlined
                            : (isDebt
                                ? Icons.credit_card_outlined
                                : (isExpense
                                    ? Icons.arrow_outward_rounded
                                    : Icons.arrow_downward_rounded));

                        final String prefix = isSavings ? '📥 ' : (isExpense ? '-' : '+');
                        final Color amountColor = isSavings
                            ? AppTheme.primary
                            : (isExpense ? AppTheme.danger : AppTheme.success);

                        return CloudPulseCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: 18,
                                  color: iconColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description != null &&
                                              tx.description!.isNotEmpty
                                          ? tx.description!
                                          : (tx.categoryName ??
                                              (isSavings
                                                  ? 'Tabungan / Simpanan'
                                                  : (isExpense
                                                      ? 'Pengeluaran'
                                                      : 'Pemasukan'))),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDarkPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tx.categoryName != null ? "${tx.categoryName!} • " : ""}${DateFormat('dd MMM yyyy').format(tx.transactionDate)}${isSavings ? " • Disimpan" : ""}${isUpcoming ? " • Akan Datang" : ""}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: isSavings
                                            ? AppTheme.primary
                                            : (isUpcoming
                                                ? AppTheme.warning
                                                : AppTheme.textDarkMuted),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$prefix${tx.amount.toRupiah}',
                                style: AppTheme.monoCurrency(
                                  color: amountColor,
                                  fontSize: 13.5,
                                  fontWeight: isSavings ? FontWeight.w700 : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _openEditTransaction(context, tx),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(
                                        Icons.edit_outlined,
                                        size: 16,
                                        color: AppTheme.textDarkMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _confirmDelete(tx),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: AppTheme.textDarkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text(
          'Hapus Transaksi',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus transaksi "${tx.description != null && tx.description!.isNotEmpty ? tx.description : (tx.categoryName ?? 'ini')}" sebesar ${tx.amount.toRupiah}?',
          style: GoogleFonts.dmSans(color: AppTheme.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: GoogleFonts.dmSans(color: AppTheme.textDarkMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTransaction(tx);
    }
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    try {
      await ref.read(transactionsProvider.notifier).deleteTransaction(tx.id);
      if (mounted) {
        AppTheme.showSuccessSnackBar(context, 'Transaksi berhasil dihapus.');
      }
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menghapus transaksi.'),
        );
      }
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: GoogleFonts.dmSans(
        color: isSelected ? Colors.white : AppTheme.textDarkSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
    );
  }

  void _openAddTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddTransactionDialog(),
    );
  }

  void _openEditTransaction(BuildContext context, TransactionModel tx) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(initialTransaction: tx),
    );
  }

  Future<void> _changePeriod(
      BuildContext context, ({int month, int year}) current) async {
    int month = current.month;
    int year = current.year;

    const monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        title: Text(
          'Pilih Periode',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Row(
          children: [
            Expanded(
              flex: 3,
              child: AppDropdownFormField<int>(
                value: month,
                labelText: 'Bulan',
                prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20, color: AppTheme.primary),
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      monthNames[m - 1],
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) => month = v ?? month,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppDropdownFormField<int>(
                value: year,
                labelText: 'Tahun',
                items: [2024, 2025, 2026, 2027, 2028].map((y) {
                  return DropdownMenuItem(
                    value: y,
                    child: Text(
                      '$y',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) => year = v ?? year,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              ref.read(selectedPeriodProvider.notifier).state =
                  (month: month, year: year);
              Navigator.pop(ctx);
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }
}
