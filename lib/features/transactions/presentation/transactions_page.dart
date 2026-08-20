// lib/features/transactions/presentation/transactions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
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
  String _filter = 'all'; // 'all', 'expense', 'income'

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(selectedPeriodProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaksi',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Period Selector Button
          IconButton(
            icon: const Icon(Icons.date_range_rounded, size: 20),
            tooltip: 'Ganti Periode',
            onPressed: () => _changePeriod(context, period),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter Chips Row ───────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Semua', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pengeluaran', 'expense'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pemasukan', 'income'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Transactions List ──────────────────────────────────────
              Expanded(
                child: transactionsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (txList) {
                    final filtered = txList.where((t) {
                      if (_filter == 'expense') return t.type == TransactionType.expense;
                      if (_filter == 'income') return t.type == TransactionType.income;
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return EmptyStateWidget(
                        icon: Icons.receipt_long_rounded,
                        title: 'Belum Ada Transaksi',
                        description:
                            'Catat pengeluaran harianmu untuk mengontrol sisa budget kategori.',
                        actionLabel: 'Catat Pengeluaran',
                        onAction: () => _openAddTransaction(context),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final tx = filtered[i];
                        final isExpense = tx.type == TransactionType.expense;

                        return CloudPulseCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isExpense
                                      ? AppTheme.danger.withValues(alpha: 0.12)
                                      : AppTheme.success.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMedium),
                                ),
                                child: Icon(
                                  isExpense
                                      ? Icons.arrow_outward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 18,
                                  color: isExpense
                                      ? AppTheme.danger
                                      : AppTheme.success,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.description ??
                                          tx.categoryName ??
                                          (isExpense ? 'Pengeluaran' : 'Pemasukan'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textDarkPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${tx.categoryName != null ? "${tx.categoryName!} • " : ""}${DateFormat('dd MMM yyyy').format(tx.transactionDate)}',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: AppTheme.textDarkMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isExpense ? '-' : '+'}${tx.amount.toRupiah}',
                                style: AppTheme.monoCurrency(
                                  color: isExpense
                                      ? AppTheme.danger
                                      : AppTheme.success,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppTheme.textDarkMuted),
                                onPressed: () => ref
                                    .read(transactionsProvider.notifier)
                                    .deleteTransaction(tx.id),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransaction(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Catat Transaksi',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceDarkAlt,
      labelStyle: GoogleFonts.dmSans(
        color: isSelected ? Colors.white : AppTheme.textDarkSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Future<void> _changePeriod(
      BuildContext context, ({int month, int year}) current) async {
    int month = current.month;
    int year = current.year;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Pilih Periode'),
        content: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: month,
                items: List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(value: m, child: Text('Bulan $m'));
                }).toList(),
                onChanged: (v) => month = v ?? month,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: year,
                items: [2024, 2025, 2026, 2027].map((y) {
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }).toList(),
                onChanged: (v) => year = v ?? year,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
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
