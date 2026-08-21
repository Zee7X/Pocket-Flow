// lib/features/dashboard/presentation/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/domain/auth_state.dart' as domain;
import '../../auth/presentation/providers/auth_provider.dart';
import '../../salary_allocation/domain/monthly_budget.dart';
import '../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/widgets/add_transaction_dialog.dart';
import 'providers/dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isBalanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final period = ref.watch(selectedPeriodProvider);
    final authState = ref.watch(authProvider);

    final String greetingName = switch (authState) {
      domain.AuthAuthenticated(:final displayName, :final email) =>
        displayName != null && displayName.trim().isNotEmpty
            ? displayName.trim()
            : (email != null ? email.split('@').first : 'User'),
      _ => 'User',
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'U',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Halo, $greetingName 👋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getCurrentPeriod(period),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.textDarkSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.tune_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Aturan & Kategori',
            onPressed: () => context.push(AppRoutes.categoriesRules),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.assessment_rounded,
                  size: 18, color: AppTheme.primary),
            ),
            tooltip: 'Laporan Keuangan',
            onPressed: () => context.push(AppRoutes.reports),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderLightSubtle),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 18, color: AppTheme.textDarkSecondary),
            ),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 800,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: summaryAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (summary) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Hero Card: Royal Blue Neo-Banking Card ──────────
                    _buildHeroCard(summary, greetingName),

                    const SizedBox(height: 20),

                    // ── 2. Two-Column Stats Overview ─────────────────────────
                    _buildQuickStats(summary),

                    const SizedBox(height: 24),

                    // ── 3. Category Budgets Tracker ──────────────────────────
                    _buildCategoryBudgets(summary.categoryBudgets, summary.daysRemainingInMonth),

                    const SizedBox(height: 24),

                    // ── 4. Recent Transactions ──────────────────────────────
                    _buildRecentTransactions(summary.recentTransactions),

                    const SizedBox(height: 28),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. Royal Blue Hero Card (Matching Reference Image) ────────────────────
  Widget _buildHeroCard(DashboardSummary summary, String userName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: AppTheme.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Status Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Safe Spending Hari Ini',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isBalanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Large Balance Number
          Text(
            _isBalanceVisible
                ? summary.safeSpendingToday.toRupiah
                : 'Rp ••••••••',
            style: AppTheme.monoCurrency(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 4),

          // Days remaining subtitle
          Text(
            summary.totalAllocated == 0
                ? 'Belum ada alokasi gaji bulan ini'
                : '${summary.daysRemainingInMonth} hari tersisa • Sisa Budget: ${summary.remainingBudget.toRupiah}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),

          const SizedBox(height: 22),

          // 4 Circular Quick Action Buttons (Transfer, Add, Top Up, Pay Bills style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildCircularAction(
                  icon: Icons.arrow_outward_rounded,
                  label: 'Catat Keluar',
                  onTap: () =>
                      _openAddTransaction(context, TransactionType.expense),
                ),
              ),
              Expanded(
                child: _buildCircularAction(
                  icon: Icons.add_rounded,
                  label: 'Catat Masuk',
                  onTap: () =>
                      _openAddTransaction(context, TransactionType.income),
                ),
              ),
              Expanded(
                child: _buildCircularAction(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Alokasi Gaji',
                  onTap: () => context.go(AppRoutes.salary),
                ),
              ),
              Expanded(
                child: _buildCircularAction(
                  icon: Icons.pie_chart_rounded,
                  label: 'Laporan',
                  onTap: () => context.push(AppRoutes.reports),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── 2. Quick Stats Overview (Allocated vs Spent) ──────────────────────────
  Widget _buildQuickStats(DashboardSummary summary) {
    return Row(
      children: [
        Expanded(
          child: CloudPulseCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      color: AppTheme.success, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Alokasi',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.textDarkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.totalAllocated.toRupiahCompact,
                        style: AppTheme.monoCurrency(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CloudPulseCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelRed,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.arrow_outward_rounded,
                      color: AppTheme.danger, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terpakai',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.textDarkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary.totalSpent.toRupiahCompact,
                        style: AppTheme.monoCurrency(
                          fontSize: 15,
                          color: summary.totalSpent > 0
                              ? AppTheme.danger
                              : AppTheme.textDarkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── 3. Category Budgets Tracker (Card Style Matching Reference) ─────────
  Widget _buildCategoryBudgets(List<MonthlyBudget> budgets, int daysRemaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Budget Kategori Bulan Ini',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.categoriesRules),
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (budgets.isEmpty)
          CloudPulseCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.tune_rounded, size: 36, color: AppTheme.textDarkMuted),
                  const SizedBox(height: 8),
                  Text(
                    'Belum Ada Budget Kategori',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Input gaji untuk membuat alokasi otomatis',
                    style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.textDarkSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.salary),
                    child: const Text('Input Gajian'),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: budgets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final budget = budgets[i];
              final isOverBudget = budget.isOverBudget;
              final pct = (budget.spentPercentage * 100).toStringAsFixed(0);

              // Daily limit — only for variable expense categories
              final isDailyTrackable = budget.isDailyTrackable;
              final dailyLimit = isDailyTrackable && daysRemaining > 0
                  ? (budget.remainingAmount / daysRemaining).floor()
                  : 0;

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () {
                  final initialAmount = budget.categoryIsFixed
                      ? (budget.remainingAmount > 0
                          ? budget.remainingAmount
                          : budget.allocatedAmount)
                      : null;

                  showDialog(
                    context: context,
                    builder: (_) => AddTransactionDialog(
                      initialType: TransactionType.expense,
                      initialCategoryId: budget.categoryId,
                      initialAmount: initialAmount,
                    ),
                  );
                },
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isOverBudget
                                  ? AppTheme.pastelRed
                                  : AppTheme.pastelBlue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isOverBudget
                                  ? Icons.warning_amber_rounded
                                  : Icons.folder_outlined,
                              size: 15,
                              color: isOverBudget
                                  ? AppTheme.danger
                                  : AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              budget.categoryName ?? 'Kategori',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: budget.spentAmount.toRupiah,
                                    style: AppTheme.monoCurrency(
                                      fontSize: 11.5,
                                      color: budget.spentAmount > 0
                                          ? AppTheme.danger
                                          : AppTheme.textDarkPrimary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' / ${budget.allocatedAmount.toRupiah}',
                                    style: AppTheme.monoCurrency(
                                      fontSize: 11.5,
                                      color: AppTheme.textDarkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: budget.spentPercentage.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppTheme.surfaceLightAlt,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOverBudget
                                ? AppTheme.danger
                                : budget.spentPercentage > 0.8
                                    ? AppTheme.warning
                                    : AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$pct% terpakai',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isOverBudget
                                  ? AppTheme.danger
                                  : AppTheme.textDarkSecondary,
                              fontWeight: isOverBudget
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOverBudget
                                ? 'Over Budget!'
                                : 'Sisa: ${budget.remainingAmount.toRupiah}',
                            textAlign: TextAlign.end,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isOverBudget
                                  ? AppTheme.danger
                                  : AppTheme.success,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // ── Daily limit / Fixed badge ────────────────────────────
                    const SizedBox(height: 8),
                    if (isDailyTrackable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOverBudget
                              ? AppTheme.pastelRed
                              : AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(
                            color: isOverBudget
                                ? AppTheme.danger.withValues(alpha: 0.3)
                                : AppTheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverBudget
                                  ? Icons.warning_amber_rounded
                                  : Icons.today_rounded,
                              size: 13,
                              color: isOverBudget
                                  ? AppTheme.danger
                                  : AppTheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                isOverBudget
                                    ? 'Melebihi budget!'
                                    : 'Maks hari ini: ${dailyLimit.toRupiah}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isOverBudget
                                      ? AppTheme.danger
                                      : AppTheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (budget.categoryIsFixed)
                      Row(
                        children: [
                          Icon(Icons.push_pin_rounded,
                              size: 12, color: AppTheme.textDarkMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Biaya Tetap',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.textDarkMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
          ),

      ],
    );
  }

  // ─── 4. Recent Transactions ────────────────────────────────────────────────
  Widget _buildRecentTransactions(List<TransactionModel> transactions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Transaksi Terkini',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.transactions),
              child: Text(
                'Lihat Semua',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          CloudPulseCard(
            padding: const EdgeInsets.all(24),
            child: EmptyStateWidget(
              icon: Icons.receipt_long_outlined,
              title: 'Belum Ada Transaksi',
              description: 'Catat pengeluaran harianmu untuk memantau sisa budget.',
              actionLabel: 'Catat Pengeluaran',
              onAction: () =>
                  _openAddTransaction(context, TransactionType.expense),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length.clamp(0, 5),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final tx = transactions[i];
              final isExpense = tx.type == TransactionType.expense;

              return CloudPulseCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isExpense
                            ? AppTheme.pastelRed
                            : AppTheme.pastelGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isExpense
                            ? Icons.arrow_outward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                        color: isExpense ? AppTheme.danger : AppTheme.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description != null && tx.description!.isNotEmpty
                                ? tx.description!
                                : (tx.categoryName ?? (isExpense ? 'Pengeluaran' : 'Pemasukan')),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy').format(tx.transactionDate),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.textDarkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${isExpense ? '-' : '+'}${tx.amount.toRupiah}',
                        style: AppTheme.monoCurrency(
                          fontSize: 14,
                          color: isExpense ? AppTheme.danger : AppTheme.success,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  void _openAddTransaction(BuildContext context, TransactionType type) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(initialType: type),
    );
  }

  String _getCurrentPeriod(({int month, int year}) period) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${months[period.month - 1]} ${period.year}';
  }
}
