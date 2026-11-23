// lib/features/transactions/presentation/transactions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/period_picker.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../../core/utils/date_id.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/providers/wallets_provider.dart';
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
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: AppBar(
        title: InkWell(
          onTap: () => _changePeriod(context, period),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Transaksi',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${kMonthsShortId[period.month - 1]} ${period.year}',
                  style: Ui.body(
                    size: 14,
                    color: AppTheme.primary,
                    weight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Transaksi',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _openAddTransaction(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    _buildFilterChip('Transfer', 'transfer'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Akan Datang', 'upcoming'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: transactionsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => AppErrorWidget(
                    error: e,
                    onRetry: () async => ref.invalidate(transactionsProvider),
                  ),
                  data: (transactions) {
                    final filtered = transactions.where((t) {
                      return switch (_filter) {
                        'expense' => t.type == TransactionType.expense,
                        'income' => t.type == TransactionType.income,
                        'transfer' => t.type == TransactionType.transfer,
                        'upcoming' => t.isUpcoming,
                        _ => true,
                      };
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

                    final income = filtered
                        .where((t) => t.type == TransactionType.income)
                        .fold<int>(0, (s, t) => s + t.amount);
                    final expense = filtered
                        .where((t) => t.type == TransactionType.expense)
                        .fold<int>(0, (s, t) => s + t.amount);

                    // Kelompokkan per tanggal.
                    final groups = <DateTime, List<TransactionModel>>{};
                    for (final t in filtered) {
                      final d = DateTime(
                        t.transactionDate.year,
                        t.transactionDate.month,
                        t.transactionDate.day,
                      );
                      groups.putIfAbsent(d, () => []).add(t);
                    }
                    final days = groups.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(transactionsProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: days.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Masuk',
                                      amount: income,
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _SummaryTile(
                                      label: 'Keluar',
                                      amount: expense,
                                      color: AppTheme.textDarkPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          final day = days[i - 1];
                          final items = groups[day]!;
                          final dayNet = items.fold<int>(
                            0,
                            (s, t) =>
                                s +
                                (t.type == TransactionType.income
                                    ? t.amount
                                    : (t.type == TransactionType.expense
                                          ? -t.amount
                                          : 0)),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    0,
                                    4,
                                    6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          day.isAfter(DateTime.now())
                                              ? '${dateRelativeId(day)} · Akan Datang'
                                              : dateRelativeId(day),
                                          style: Ui.body(
                                            size: 12.5,
                                            weight: FontWeight.w600,
                                            color: day.isAfter(DateTime.now())
                                                ? AppTheme.warning
                                                : AppTheme.textDarkSecondary,
                                          ),
                                        ),
                                      ),
                                      if (dayNet != 0)
                                        Text(
                                          '${dayNet > 0 ? '+' : '−'}${dayNet.abs().toRupiah}',
                                          style: Ui.amount(
                                            size: 12.5,
                                            color: AppTheme.textDarkSecondary,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                AppCard(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      for (final (j, tx) in items.indexed) ...[
                                        if (j > 0)
                                          const Divider(height: 1, indent: 64),
                                        _TxRow(
                                          tx: tx,
                                          wallets: wallets,
                                          onTap: () =>
                                              _openEditTransaction(context, tx),
                                          onDelete: () => _confirmDelete(tx),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
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
    final label = tx.description != null && tx.description!.isNotEmpty
        ? tx.description!
        : (tx.categoryName ?? 'ini');
    final confirmed = await showAppConfirm(
      context: context,
      title: 'Hapus transaksi?',
      message:
          '"$label" sebesar ${tx.amount.toRupiah} akan dihapus dan budget kategorinya disesuaikan.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (confirmed) await _deleteTransaction(tx);
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
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menghapus transaksi.',
          ),
        );
      }
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return ChoiceChip(
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      side: BorderSide(
        color: isSelected ? AppTheme.primary : const Color(0xFFE6EAF0),
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surfaceLight,
      labelStyle: GoogleFonts.dmSans(
        color: isSelected ? Colors.white : AppTheme.textDarkPrimary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) setState(() => _filter = value);
      },
    );
  }

  void _openAddTransaction(BuildContext context) {
    showAddTransaction(context);
  }

  void _openEditTransaction(BuildContext context, TransactionModel tx) {
    showAddTransaction(context, type: tx.type, initial: tx);
  }

  Future<void> _changePeriod(
    BuildContext context,
    ({int month, int year}) current,
  ) async {
    final picked = await showPeriodPicker(context, current);
    if (picked != null) {
      ref.read(selectedPeriodProvider.notifier).state = picked;
    }
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Ui.body(size: 12)),
          const SizedBox(height: 2),
          Text(amount.toRupiah, style: Ui.amount(size: 15.5, color: color)),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionModel tx;
  final List<Wallet> wallets;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TxRow({
    required this.tx,
    required this.wallets,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == TransactionType.income;
    final isTransfer = tx.type == TransactionType.transfer;
    final wallet = wallets.where((w) => w.id == tx.walletId).firstOrNull;
    final toWallet = wallets.where((w) => w.id == tx.toWalletId).firstOrNull;

    final IconData icon = isTransfer
        ? Icons.swap_horiz_rounded
        : tx.isSavings
        ? Icons.savings_outlined
        : tx.isDebt
        ? Icons.credit_card_outlined
        : (isIncome ? Icons.south_west_rounded : Icons.north_east_rounded);
    final Color color = isTransfer || tx.isSavings
        ? AppTheme.primary
        : tx.isDebt
        ? AppTheme.warning
        : (isIncome ? const Color(0xFF059669) : AppTheme.textDarkSecondary);

    final title = tx.description != null && tx.description!.isNotEmpty
        ? tx.description!
        : (tx.categoryName ??
              (isTransfer
                  ? 'Transfer'
                  : (isIncome ? 'Pemasukan' : 'Pengeluaran')));
    final meta = [
      if (isTransfer)
        '${wallet?.name ?? 'Luar'} → ${toWallet?.name ?? 'Luar'}'
      else ...[
        ?tx.categoryName,
        ?wallet?.name,
      ],
      if (tx.isUpcoming) 'Akan Datang',
    ].join(' · ');
    final sourceIcon = switch (tx.source) {
      'notification' => Icons.notifications_none_rounded,
      'ai' => Icons.auto_awesome_outlined,
      'ocr' => Icons.receipt_long_outlined,
      'import' => Icons.upload_file_outlined,
      'recurring' => Icons.event_repeat_outlined,
      'split' => Icons.groups_outlined,
      _ => null,
    };

    return InkWell(
      onTap: tx.isPendingSync ? null : onTap,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 4, 11),
        child: Row(
          children: [
            IconBadge(icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ui.body(
                            size: 14,
                            color: AppTheme.textDarkPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (sourceIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          sourceIcon,
                          size: 13,
                          color: AppTheme.textDarkMuted,
                        ),
                      ],
                      if (tx.isPendingSync) ...[
                        const SizedBox(width: 6),
                        const Tooltip(
                          message: 'Menunggu sinkron',
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 14,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.body(
                        size: 12,
                        color: tx.isUpcoming
                            ? AppTheme.warning
                            : AppTheme.textDarkSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${isTransfer ? '' : (isIncome ? '+' : '−')}${tx.amount.toRupiah}',
              style: Ui.amount(
                size: 14,
                color: isIncome
                    ? const Color(0xFF059669)
                    : AppTheme.textDarkPrimary,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opsi',
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: AppTheme.textDarkMuted,
              ),
              onSelected: (v) => v == 'edit' ? onTap() : onDelete(),
              itemBuilder: (_) => [
                if (!tx.isPendingSync)
                  const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
