// lib/features/dashboard/presentation/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../auth/domain/auth_state.dart' as domain;
import '../../auth/presentation/providers/auth_provider.dart';
import '../../salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../../transactions/presentation/widgets/add_transaction_dialog.dart';
import '../../debts_savings/presentation/providers/debts_savings_provider.dart';
import 'providers/dashboard_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupSync();
    });
  }

  Future<void> _runStartupSync() async {
    try {
      await ref.read(savingsRepositoryProvider).cleanupPhantomSavingsAndRecalibrate();
      if (mounted) {
        ref.invalidate(monthlyBudgetsProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(dashboardSummaryProvider);
      }
    } catch (_) {}
  }

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
      backgroundColor: AppTheme.canvasLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(savingsRepositoryProvider).cleanupPhantomSavingsAndRecalibrate();
            ref.invalidate(monthlyBudgetsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(dashboardSummaryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveCenter(
              maxWidth: 800,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: summaryAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (e, _) => AppErrorWidget(
                  error: e,
                  onRetry: () async {
                    ref.invalidate(monthlyBudgetsProvider);
                    ref.invalidate(transactionsProvider);
                    ref.invalidate(dashboardSummaryProvider);
                  },
                ),
                data: (summary) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 0. Top Profile & Action Header ─────────────────────
                      _buildTopHeader(greetingName, period),

                      const SizedBox(height: 16),

                      // ── 1. Hero Card: Royal Blue Neo-Banking Card ──────────
                      _buildHeroCard(summary, greetingName),

                      const SizedBox(height: 20),

                      // ── 2. Two-Column Stats Overview ─────────────────────────
                      _buildQuickStats(summary),

                      const SizedBox(height: 24),

                      // ── 3. Category Tracker / Breakdown ──────────────────────
                      if (summary.hasBudgetAllocation)
                        _buildCategoryBudgets(summary)
                      else
                        _buildUnallocatedModeSection(summary),

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
      ),
    );
  }

  // ─── 0. Top Profile & Action Header ─────────────────────────────────────────
  Widget _buildTopHeader(String greetingName, ({int month, int year}) period) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'U',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Halo, $greetingName 👋',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: () => _openPeriodPicker(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 12, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        _getCurrentPeriod(period),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildHeaderIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'Aturan & Kategori',
          color: AppTheme.primary,
          onTap: () => context.push(AppRoutes.categoriesRules),
        ),
        const SizedBox(width: 8),
        _buildHeaderIconButton(
          icon: Icons.assessment_rounded,
          tooltip: 'Laporan Keuangan',
          color: AppTheme.primary,
          onTap: () => context.push(AppRoutes.reports),
        ),
        const SizedBox(width: 8),
        _buildHeaderIconButton(
          icon: Icons.logout_rounded,
          tooltip: 'Logout',
          color: AppTheme.textDarkSecondary,
          onTap: () => ref.read(authProvider.notifier).signOut(),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          child: Container(
            padding: const EdgeInsets.all(8.5),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderLightSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  // ─── 1. Royal Blue Hero Card (Dual-Mode: Allocation vs Cashflow) ───────────
  Widget _buildHeroCard(DashboardSummary summary, String userName) {
    final bool hasAllocation = summary.hasBudgetAllocation;
    final bool isSurplus = summary.netCashflow >= 0;

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
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Sisa Saldo Kas Bulan Ini',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasAllocation
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isSurplus
                                ? AppTheme.success.withValues(alpha: 0.35)
                                : AppTheme.danger.withValues(alpha: 0.35)),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        hasAllocation
                            ? 'Budgeting'
                            : (isSurplus ? 'Surplus' : 'Defisit'),
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _isBalanceVisible = !_isBalanceVisible),
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

          // Large Balance Number: Real Remaining Cashflow
          Text(
            _isBalanceVisible
                ? (summary.netCashflow >= 0
                    ? summary.netCashflow.toRupiah
                    : '-${summary.netCashflow.abs().toRupiah}')
                : 'Rp ••••••••',
            style: AppTheme.monoCurrency(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 4),

          // Days remaining / Budget subtitle
          Text(
            hasAllocation
                ? 'Sisa Budget: ${summary.remainingBudget.toRupiah} • Sisa ${summary.daysRemainingInMonth} hari'
                : 'Pemasukan: ${summary.totalIncome.toRupiah} • Pengeluaran: ${summary.totalExpense.toRupiah}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.82),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),

          // Integrated Smart Daily Safe Spending Card
          if (hasAllocation) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: summary.safeSpendingToday > 0
                          ? const Color(0xFF86EFAC).withValues(alpha: 0.2)
                          : const Color(0xFFFDE047).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      summary.safeSpendingToday > 0
                          ? Icons.bolt_rounded
                          : Icons.schedule_rounded,
                      size: 15,
                      color: summary.safeSpendingToday > 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDE047),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Safe Spending Hari Ini',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: summary.safeSpendingToday > 0
                                    ? const Color(0xFF86EFAC).withValues(alpha: 0.2)
                                    : const Color(0xFFFDE047).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                summary.safeSpendingToday > 0
                                    ? 'Sisa Hari Ini'
                                    : (summary.variableSpentToday > 0
                                        ? 'Hari Ini Habis'
                                        : 'Belum Diset'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: summary.safeSpendingToday > 0
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFFFDE047),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              summary.safeSpendingToday > 0
                                  ? summary.safeSpendingToday.toRupiah
                                  : 'Rp0',
                              style: AppTheme.monoCurrency(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summary.safeSpendingToday > 0
                                    ? 'Jatah ${summary.dailyQuotaToday.toRupiahCompact}/hari'
                                    : (summary.daysRemainingInMonth > 1
                                        ? 'Mulai besok: ${summary.dailyQuotaTomorrow.toRupiahCompact}/hr'
                                        : 'Terpakai ${summary.variableSpentToday.toRupiahCompact}'),
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // 4 Circular Quick Action Buttons
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

  // ─── 2. Quick Stats Overview (Dual-Mode: Allocation vs Actual Cashflow) ───
  Widget _buildQuickStats(DashboardSummary summary) {
    final bool hasAllocation = summary.hasBudgetAllocation;

    final String firstLabel =
        hasAllocation ? 'Total Alokasi' : 'Total Pemasukan';
    final String firstAmount = hasAllocation
        ? summary.totalAllocated.toRupiahCompact
        : summary.totalIncome.toRupiahCompact;
    final IconData firstIcon = hasAllocation
        ? Icons.account_balance_wallet_rounded
        : Icons.arrow_downward_rounded;
    final Color firstColor = AppTheme.success;
    final Color firstBg = AppTheme.pastelGreen;

    final bool showSavedPrimary = hasAllocation && summary.totalSavedInBudget > 0 && summary.totalBudgetSpent == 0;

    final String secondLabel = hasAllocation
        ? (showSavedPrimary ? 'Tabungan' : 'Total Terpakai')
        : 'Pengeluaran';
    final String secondAmount = hasAllocation
        ? (showSavedPrimary ? summary.totalSavedInBudget.toRupiahCompact : summary.totalBudgetSpent.toRupiahCompact)
        : summary.totalExpense.toRupiahCompact;
    final IconData secondIcon = showSavedPrimary ? Icons.savings_outlined : Icons.arrow_outward_rounded;
    final Color secondColor = showSavedPrimary ? AppTheme.primary : AppTheme.danger;
    final Color secondBg = showSavedPrimary ? AppTheme.pastelBlue : AppTheme.pastelRed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CloudPulseCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: firstBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Icon(firstIcon, color: firstColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          firstLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.textDarkSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          firstAmount,
                          style: AppTheme.monoCurrency(
                            fontSize: 15,
                            color: hasAllocation
                                ? AppTheme.textDarkPrimary
                                : AppTheme.success,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CloudPulseCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: secondBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                    child: Icon(secondIcon, color: secondColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          secondLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.textDarkSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          secondAmount,
                          style: AppTheme.monoCurrency(
                            fontSize: 15,
                            color: showSavedPrimary
                                ? AppTheme.primary
                                : ((hasAllocation
                                            ? summary.totalBudgetSpent
                                            : summary.totalExpense) >
                                        0
                                    ? AppTheme.danger
                                    : AppTheme.textDarkPrimary),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 3A. Unallocated Mode Section (Banner + Category Expense Breakdown) ───
  Widget _buildUnallocatedModeSection(DashboardSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Smart Prompt Banner ──────────────────────────────────
        InkWell(
          onTap: () => context.go(AppRoutes.salary),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.08),
                  AppTheme.pastelBlue.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ingin Budget Otomatis dari Gaji?',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDarkPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kunci pos belanja & amankan sisa uang bebas.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.textDarkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Text(
                    'Atur Gaji',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Actual Category Expenses Breakdown ──────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Pengeluaran per Kategori',
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
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (summary.categoryExpenses.isEmpty)
          CloudPulseCard(
            padding: const EdgeInsets.all(22),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 36,
                    color: AppTheme.textDarkMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum Ada Pengeluaran Bulan Ini',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Catat transaksi harian untuk melihat ringkasan belanja.',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.textDarkSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openAddTransaction(
                        context, TransactionType.expense),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Catat Pengeluaran'),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.categoryExpenses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final cat = summary.categoryExpenses[i];
              final pct = (cat.percentage * 100).toStringAsFixed(0);

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () => _openAddTransaction(
                  context,
                  TransactionType.expense,
                  initialCategoryId:
                      cat.categoryId == 'uncategorized' ? null : cat.categoryId,
                ),
                child: CloudPulseCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.pastelBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_outlined,
                              size: 16,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.categoryName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textDarkPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              cat.totalAmount.toRupiah,
                              style: AppTheme.monoCurrency(
                                fontSize: 13,
                                color: AppTheme.danger,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cat.percentage.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppTheme.surfaceLightAlt,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '$pct% dari total belanja',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.textDarkSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Catat Lagi +',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
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

  // ─── 3B. Category Budgets Tracker (Card Style Matching Reference) ─────────
  Widget _buildCategoryBudgets(DashboardSummary summary) {
    final budgets = summary.categoryBudgets;
    final daysRemaining = summary.daysRemainingInMonth;

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
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600),
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
                  Icon(Icons.tune_rounded,
                      size: 36, color: AppTheme.textDarkMuted),
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
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: AppTheme.textDarkSecondary),
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
              final isSavings = budget.isSavings;
              final isDebt = budget.isDebt;
              final isOverBudget = budget.isOverBudget && !isSavings;
              final pct = (budget.spentPercentage * 100).toStringAsFixed(0);
              final isSavedFull = isSavings && budget.spentAmount >= budget.allocatedAmount;

              // Daily limit & Today's spending for variable expense categories
              final isDailyTrackable = budget.isDailyTrackable;
              final int spentToday = summary.spentTodayByCat[budget.categoryId] ?? 0;
              final int remainingBeforeToday = budget.remainingAmount + spentToday;
              final int dailyQuotaToday = daysRemaining > 0
                  ? (remainingBeforeToday / daysRemaining).floor()
                  : 0;
              final int remainingDailyQuota = dailyQuotaToday - spentToday;
              final int dailyQuotaTomorrow = daysRemaining > 1
                  ? (budget.remainingAmount / (daysRemaining - 1)).floor()
                  : budget.remainingAmount;

              // Icons and Colors
              final IconData catIcon = isSavings
                  ? Icons.savings_outlined
                  : (isDebt
                      ? Icons.credit_card_outlined
                      : (isOverBudget
                          ? Icons.warning_amber_rounded
                          : Icons.folder_outlined));
              final Color catColor = isSavings
                  ? AppTheme.primary
                  : (isDebt
                      ? AppTheme.warning
                      : (isOverBudget ? AppTheme.danger : AppTheme.primary));
              final Color catBg = isSavings
                  ? AppTheme.pastelBlue
                  : (isDebt
                      ? AppTheme.pastelAmber
                      : (isOverBudget ? AppTheme.pastelRed : AppTheme.pastelBlue));

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: catBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              catIcon,
                              size: 15,
                              color: catColor,
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
                                      color: isSavings
                                          ? (isSavedFull
                                              ? AppTheme.success
                                              : AppTheme.primary)
                                          : (budget.spentAmount > 0
                                              ? (isOverBudget
                                                  ? AppTheme.danger
                                                  : AppTheme.textDarkPrimary)
                                              : AppTheme.textDarkPrimary),
                                      fontWeight: isSavings
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' / ${budget.allocatedAmount.toRupiah}',
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
                            isSavings
                                ? (isSavedFull
                                    ? AppTheme.success
                                    : AppTheme.primary)
                                : (isOverBudget
                                    ? AppTheme.danger
                                    : budget.spentPercentage > 0.8
                                        ? AppTheme.warning
                                        : AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isSavings
                                ? '$pct% tersimpan'
                                : (isDebt ? '$pct% terbayar' : '$pct% terpakai'),
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isSavings
                                  ? (isSavedFull
                                      ? AppTheme.success
                                      : AppTheme.primary)
                                  : (isOverBudget
                                      ? AppTheme.danger
                                      : AppTheme.textDarkSecondary),
                              fontWeight: (isOverBudget || isSavedFull)
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isSavings
                                  ? (isSavedFull
                                      ? 'Target Terkumpul ✨'
                                      : 'Sisa target: ${budget.remainingAmount.toRupiah}')
                                  : (isDebt
                                      ? (budget.remainingAmount <= 0
                                          ? 'Lunas ✨'
                                          : 'Sisa: ${budget.remainingAmount.toRupiah}')
                                      : (isOverBudget
                                          ? 'Over Budget!'
                                          : 'Sisa: ${budget.remainingAmount.toRupiah}')),
                              textAlign: TextAlign.end,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: isSavings
                                    ? (isSavedFull
                                        ? AppTheme.success
                                        : AppTheme.primary)
                                    : (isOverBudget
                                        ? AppTheme.danger
                                        : AppTheme.success),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // ── Daily limit / Fixed / Savings badge ────────────────────────────
                      const SizedBox(height: 8),
                      if (isSavings)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.savings_rounded,
                                  size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Tabungan & Simpanan Aset',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isDebt)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelAmber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.credit_card_outlined,
                                  size: 12, color: AppTheme.warning),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Pos Cicilan & Utang',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.warning,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (isDailyTrackable)
                        Builder(
                          builder: (context) {
                            final Color badgeBg;
                            final Color badgeBorder;
                            final Color badgeText;
                            final IconData badgeIcon;
                            final String badgeLabel;

                            final String tooltipMsg;

                            if (isOverBudget) {
                              badgeBg = AppTheme.pastelRed;
                              badgeBorder = AppTheme.danger.withValues(alpha: 0.3);
                              badgeText = AppTheme.danger;
                              badgeIcon = Icons.warning_amber_rounded;
                              badgeLabel = 'Over Budget!';
                              tooltipMsg = 'Pengeluaran telah melebihi budget bulanan sebesar ${(budget.spentAmount - budget.allocatedAmount).toRupiah}';
                            } else if (spentToday == 0) {
                              badgeBg = AppTheme.primary.withValues(alpha: 0.08);
                              badgeBorder = AppTheme.primary.withValues(alpha: 0.2);
                              badgeText = AppTheme.primary;
                              badgeIcon = Icons.today_rounded;
                              badgeLabel = 'Jatah hari ini: ${dailyQuotaToday.toRupiah}';
                              tooltipMsg = 'Jatah aman belanja hari ini: ${dailyQuotaToday.toRupiah} (tersisa $daysRemaining hari)';
                            } else if (spentToday > 0 && remainingDailyQuota > 0) {
                              badgeBg = AppTheme.pastelGreen;
                              badgeBorder = AppTheme.success.withValues(alpha: 0.3);
                              badgeText = AppTheme.success;
                              badgeIcon = Icons.check_circle_outline_rounded;
                              badgeLabel = 'Sisa hari ini: ${remainingDailyQuota.toRupiah}';
                              tooltipMsg = 'Terpakai ${spentToday.toRupiah} hari ini (dari jatah ${dailyQuotaToday.toRupiah}). Mulai besok: ${dailyQuotaTomorrow.toRupiah}/hari';
                            } else {
                              // Kuota hari ini sudah habis
                              badgeBg = AppTheme.pastelOrange;
                              badgeBorder = AppTheme.warning.withValues(alpha: 0.4);
                              badgeText = const Color(0xFFD97706);
                              badgeIcon = Icons.info_outline_rounded;
                              badgeLabel = 'Jatah hari ini habis';
                              tooltipMsg = 'Hari ini sudah terpakai ${spentToday.toRupiah}. Jatah aman mulai besok: ${dailyQuotaTomorrow.toRupiah}/hari ($daysRemaining hari tersisa)';
                            }

                            return Tooltip(
                              message: tooltipMsg,
                              triggerMode: TooltipTriggerMode.tap,
                              preferBelow: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMedium),
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      badgeIcon,
                                      size: 13,
                                      color: badgeText,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        badgeLabel,
                                        style: GoogleFonts.dmSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: badgeText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 11,
                                      color: badgeText.withValues(alpha: 0.7),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600),
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
              description:
                  'Catat pengeluaran harianmu untuk memantau sisa budget.',
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
              final isSavings = tx.isSavings;
              final isDebt = tx.isDebt;

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
                      width: 38,
                      height: 38,
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
                                        : (isExpense ? 'Pengeluaran' : 'Pemasukan'))),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                          Text(
                            '${tx.categoryName != null ? "${tx.categoryName!} • " : ""}${DateFormat('dd MMM yyyy').format(tx.transactionDate)}${isSavings ? " • Disimpan" : ""}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: isSavings
                                  ? AppTheme.primary
                                  : AppTheme.textDarkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '$prefix${tx.amount.toRupiah}',
                        style: AppTheme.monoCurrency(
                          fontSize: 14,
                          fontWeight: isSavings ? FontWeight.w700 : FontWeight.w600,
                          color: amountColor,
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

  void _openAddTransaction(BuildContext context, TransactionType type,
      {String? initialCategoryId, int? initialAmount}) {
    showDialog(
      context: context,
      builder: (_) => AddTransactionDialog(
        initialType: type,
        initialCategoryId: initialCategoryId,
        initialAmount: initialAmount,
      ),
    );
  }

  void _openPeriodPicker(BuildContext context) {
    final current = ref.read(selectedPeriodProvider);
    int month = current.month;
    int year = current.year;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                prefixIcon: const Icon(Icons.calendar_month_outlined,
                    size: 20, color: AppTheme.primary),
                items: List.generate(12, (i) => i + 1).map((m) {
                  const months = [
                    'Januari',
                    'Februari',
                    'Maret',
                    'April',
                    'Mei',
                    'Juni',
                    'Juli',
                    'Agustus',
                    'September',
                    'Oktober',
                    'November',
                    'Desember',
                  ];
                  return DropdownMenuItem(
                    value: m,
                    child: Text(
                      months[m - 1],
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

  String _getCurrentPeriod(({int month, int year}) period) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${months[period.month - 1]} ${period.year}';
  }
}
