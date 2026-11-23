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
import '../../../core/widgets/app_shell.dart' show openQuickAddModal;
import '../../../core/widgets/period_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../capture/presentation/providers/capture_provider.dart';
import '../../insights/presentation/widgets/insights_card.dart';
import '../../recurring/domain/recurring_bill.dart';
import '../../recurring/presentation/providers/recurring_provider.dart';
import '../../smart/presentation/smart_input_sheet.dart';
import '../../wallets/presentation/providers/wallets_provider.dart';

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
      await ref.read(savingsRepositoryProvider).recalibrateRecentBudgets();
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
            await ref
                .read(savingsRepositoryProvider)
                .recalibrateRecentBudgets();
            ref.invalidate(monthlyBudgetsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(walletsProvider);
            ref.invalidate(recurringBillsProvider);
            await ref.read(pendingCapturesProvider.notifier).drainNative();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveCenter(
              maxWidth: 800,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  final pending = ref.watch(pendingCountProvider);
                  final upcoming = ref.watch(upcomingBillsProvider);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTopHeader(greetingName, period),
                      const SizedBox(height: 16),
                      if (pending > 0) ...[
                        _buildPendingBanner(pending),
                        const SizedBox(height: 12),
                      ],
                      _buildHeroCard(summary, greetingName),
                      const SizedBox(height: 12),
                      _buildQuickStats(summary),
                      if (upcoming.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildUpcomingBills(upcoming),
                      ],
                      const SizedBox(height: 24),
                      const InsightsCard(limit: 3),
                      const SizedBox(height: 24),
                      if (summary.hasBudgetAllocation)
                        _buildCategoryBudgets(summary)
                      else
                        _buildUnallocatedModeSection(summary),
                      const SizedBox(height: 24),
                      _buildWalletsStrip(),
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

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildTopHeader(String greetingName, ({int month, int year}) period) {
    final pending = ref.watch(pendingCountProvider);
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text(
            greetingName.isNotEmpty ? greetingName[0].toUpperCase() : 'U',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
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
                'Halo, $greetingName',
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
                    Flexible(
                      child: Text(
                        _getCurrentPeriod(period),
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: AppTheme.textDarkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppTheme.textDarkSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildHeaderIconButton(
          icon: Icons.inbox_outlined,
          tooltip: 'Perlu Ditinjau',
          badge: pending,
          onTap: () => context.push(AppRoutes.inbox),
        ),
        const SizedBox(width: 4),
        _buildHeaderIconButton(
          icon: Icons.insert_chart_outlined_rounded,
          tooltip: 'Laporan',
          onTap: () => context.push(AppRoutes.reports),
        ),
        const SizedBox(width: 4),
        _buildHeaderIconButton(
          icon: Icons.menu_rounded,
          tooltip: 'Lainnya',
          onTap: () => context.push(AppRoutes.more),
        ),
      ],
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        backgroundColor: AppTheme.danger,
        child: Icon(icon, size: 22, color: AppTheme.textDarkPrimary),
      ),
    );
  }

  Widget _buildPendingBanner(int pending) {
    return Material(
      color: AppTheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(AppRoutes.inbox),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$pending transaksi terdeteksi, menunggu ditinjau',
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────
  Widget _buildHeroCard(DashboardSummary summary, String userName) {
    final bool hasAllocation = summary.hasBudgetAllocation;
    final white70 = Colors.white.withValues(alpha: 0.72);
    String hide(String v) => _isBalanceVisible ? v : 'Rp ••••••';

    final quota = summary.dailyQuotaToday;
    final spentToday = summary.variableSpentToday;
    final progress = quota > 0 ? (spentToday / quota).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.heroSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasAllocation
                      ? 'Safe Spending Hari Ini'
                      : 'Sisa Saldo Kas Bulan Ini',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              InkWell(
                onTap: () =>
                    setState(() => _isBalanceVisible = !_isBalanceVisible),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _isBalanceVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasAllocation
                ? hide(summary.safeSpendingToday.toRupiah)
                : hide(
                    summary.netCashflow >= 0
                        ? summary.netCashflow.toRupiah
                        : '-${summary.netCashflow.abs().toRupiah}',
                  ),
            style: Ui.amount(
              size: 30,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasAllocation
                ? (summary.safeSpendingToday > 0
                      ? 'Jatah ${quota.toRupiahCompact}/hari, terpakai ${spentToday.toRupiahCompact} hari ini'
                      : (summary.daysRemainingInMonth > 1
                            ? 'Jatah hari ini sudah terpakai. Mulai besok ${summary.dailyQuotaTomorrow.toRupiahCompact}/hari'
                            : 'Terpakai ${spentToday.toRupiahCompact} hari ini'))
                : 'Pemasukan ${summary.totalIncome.toRupiahCompact} · Pengeluaran ${summary.totalExpense.toRupiahCompact}',
            style: GoogleFonts.dmSans(fontSize: 12.5, color: white70),
            maxLines: 2,
          ),
          if (hasAllocation && quota > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
              ),
            ),
          ],
          if (hasAllocation) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _heroStat(
                    'Sisa budget · ${summary.daysRemainingInMonth} hari lagi',
                    hide(summary.remainingBudget.toRupiahCompact),
                  ),
                ),
                Expanded(
                  child: _heroStat(
                    'Saldo kas bulan ini',
                    hide(
                      summary.netCashflow >= 0
                          ? summary.netCashflow.toRupiahCompact
                          : '-${summary.netCashflow.abs().toRupiahCompact}',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _heroAction(Icons.mic_none_rounded, 'Bicara', () => showVoiceCapture(context)),
              _heroAction(Icons.auto_awesome_outlined, 'Ketik', () => showSmartInputSheet(context)),
              _heroAction(Icons.receipt_long_outlined, 'Scan struk',
                  () => showSmartInputSheet(context, start: SmartInputStart.receipt)),
              _heroAction(Icons.edit_note_rounded, 'Manual', () => openQuickAddModal(context)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: Ui.amount(size: 15, color: Colors.white)),
        if (sub != null)
          Text(
            sub,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
      ],
    );
  }

  Widget _heroAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tagihan dekat jatuh tempo ────────────────────────────────────────────
  Widget _buildUpcomingBills(List<RecurringBill> bills) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Tagihan minggu ini',
          actionLabel: 'Semua',
          onAction: () => context.push(AppRoutes.bills),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (i, b) in bills.take(4).indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                ListRow(
                  title: b.name,
                  subtitle: () {
                    final d = b.daysUntilDue(now);
                    final when = d < 0
                        ? 'lewat ${-d} hari'
                        : d == 0
                        ? 'hari ini'
                        : d == 1
                        ? 'besok'
                        : '$d hari lagi';
                    return '${b.amount.toRupiah} · $when';
                  }(),
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(recurringBillsProvider.notifier)
                            .markPaid(b);
                        if (mounted) {
                          AppTheme.showSuccessSnackBar(
                            context,
                            '${b.name} dicatat lunas.',
                          );
                        }
                      } catch (_) {
                        if (mounted) {
                          AppTheme.showErrorSnackBar(
                            context,
                            'Gagal mencatat pembayaran.',
                          );
                        }
                      }
                    },
                    child: const Text('Sudah bayar'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── Dompet ───────────────────────────────────────────────────────────────
  Widget _buildWalletsStrip() {
    final wallets = ref.watch(walletsProvider).value ?? const [];
    if (wallets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Dompet',
            actionLabel: 'Kelola',
            onAction: () => context.push(AppRoutes.wallets),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: wallets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final w = wallets[i];
                return SizedBox(
                  width: 150,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onTap: () => context.push(AppRoutes.wallets),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: w.displayColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                w.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Ui.body(size: 12.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isBalanceVisible
                              ? (w.balance < 0
                                    ? '-${w.balance.abs().toRupiah}'
                                    : w.balance.toRupiah)
                              : 'Rp ••••',
                          style: Ui.amount(size: 14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(DashboardSummary summary) {
    final bool hasAllocation = summary.hasBudgetAllocation;

    final String firstLabel = hasAllocation
        ? 'Total Alokasi'
        : 'Total Pemasukan';
    final String firstAmount = hasAllocation
        ? summary.totalAllocated.toRupiahCompact
        : summary.totalIncome.toRupiahCompact;
    final IconData firstIcon = hasAllocation
        ? Icons.account_balance_wallet_rounded
        : Icons.arrow_downward_rounded;
    final Color firstColor = AppTheme.success;
    final Color firstBg = AppTheme.pastelGreen;

    final bool showSavedPrimary =
        hasAllocation &&
        summary.totalSavedInBudget > 0 &&
        summary.totalBudgetSpent == 0;

    final String secondLabel = hasAllocation
        ? (showSavedPrimary ? 'Tabungan' : 'Total Terpakai')
        : 'Pengeluaran';
    final String secondAmount = hasAllocation
        ? (showSavedPrimary
              ? summary.totalSavedInBudget.toRupiahCompact
              : summary.totalBudgetSpent.toRupiahCompact)
        : summary.totalExpense.toRupiahCompact;
    final IconData secondIcon = showSavedPrimary
        ? Icons.savings_outlined
        : Icons.arrow_outward_rounded;
    final Color secondColor = showSavedPrimary
        ? AppTheme.primary
        : AppTheme.danger;
    final Color secondBg = showSavedPrimary
        ? AppTheme.pastelBlue
        : AppTheme.pastelRed;

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
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
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
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                    onPressed: () =>
                        _openAddTransaction(context, TransactionType.expense),
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
                  initialCategoryId: cat.categoryId == 'uncategorized'
                      ? null
                      : cat.categoryId,
                ),
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                  Icon(
                    Icons.tune_rounded,
                    size: 36,
                    color: AppTheme.textDarkMuted,
                  ),
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
                      fontSize: 12,
                      color: AppTheme.textDarkSecondary,
                    ),
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
              final isSavedFull =
                  isSavings && budget.spentAmount >= budget.allocatedAmount;

              // Daily limit & Today's spending for variable expense categories
              final isDailyTrackable = budget.isDailyTrackable;
              final int spentToday =
                  summary.spentTodayByCat[budget.categoryId] ?? 0;
              final int remainingBeforeToday =
                  budget.remainingAmount + spentToday;
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
                        : (isOverBudget
                              ? AppTheme.pastelRed
                              : AppTheme.pastelBlue));

              return InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                onTap: () {
                  final initialAmount = budget.categoryIsFixed
                      ? (budget.remainingAmount > 0
                            ? budget.remainingAmount
                            : budget.allocatedAmount)
                      : null;

                  showAddTransaction(
                    context,
                    type: TransactionType.expense,
                    categoryId: budget.categoryId,
                    amount: initialAmount,
                  );
                },
                child: CloudPulseCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                            child: Icon(catIcon, size: 15, color: catColor),
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
                                                      : AppTheme
                                                            .textDarkPrimary)
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
                                : (isDebt
                                      ? '$pct% terbayar'
                                      : '$pct% terpakai'),
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
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.savings_rounded,
                                size: 12,
                                color: AppTheme.primary,
                              ),
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
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.pastelAmber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.credit_card_outlined,
                                size: 12,
                                color: AppTheme.warning,
                              ),
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
                              badgeBorder = AppTheme.danger.withValues(
                                alpha: 0.3,
                              );
                              badgeText = AppTheme.danger;
                              badgeIcon = Icons.warning_amber_rounded;
                              badgeLabel = 'Over Budget!';
                              tooltipMsg =
                                  'Pengeluaran telah melebihi budget bulanan sebesar ${(budget.spentAmount - budget.allocatedAmount).toRupiah}';
                            } else if (spentToday == 0) {
                              badgeBg = AppTheme.primary.withValues(
                                alpha: 0.08,
                              );
                              badgeBorder = AppTheme.primary.withValues(
                                alpha: 0.2,
                              );
                              badgeText = AppTheme.primary;
                              badgeIcon = Icons.today_rounded;
                              badgeLabel =
                                  'Jatah hari ini: ${dailyQuotaToday.toRupiah}';
                              tooltipMsg =
                                  'Jatah aman belanja hari ini: ${dailyQuotaToday.toRupiah} (tersisa $daysRemaining hari)';
                            } else if (spentToday > 0 &&
                                remainingDailyQuota > 0) {
                              badgeBg = AppTheme.pastelGreen;
                              badgeBorder = AppTheme.success.withValues(
                                alpha: 0.3,
                              );
                              badgeText = AppTheme.success;
                              badgeIcon = Icons.check_circle_outline_rounded;
                              badgeLabel =
                                  'Sisa hari ini: ${remainingDailyQuota.toRupiah}';
                              tooltipMsg =
                                  'Terpakai ${spentToday.toRupiah} hari ini (dari jatah ${dailyQuotaToday.toRupiah}). Mulai besok: ${dailyQuotaTomorrow.toRupiah}/hari';
                            } else {
                              // Kuota hari ini sudah habis
                              badgeBg = AppTheme.pastelOrange;
                              badgeBorder = AppTheme.warning.withValues(
                                alpha: 0.4,
                              );
                              badgeText = const Color(0xFFD97706);
                              badgeIcon = Icons.info_outline_rounded;
                              badgeLabel = 'Jatah hari ini habis';
                              tooltipMsg =
                                  'Hari ini sudah terpakai ${spentToday.toRupiah}. Jatah aman mulai besok: ${dailyQuotaTomorrow.toRupiah}/hari ($daysRemaining hari tersisa)';
                            }

                            return Tooltip(
                              message: tooltipMsg,
                              triggerMode: TooltipTriggerMode.tap,
                              preferBelow: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  border: Border.all(color: badgeBorder),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(badgeIcon, size: 13, color: badgeText),
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
                            Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color: AppTheme.textDarkMuted,
                            ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
                        : (isExpense
                              ? AppTheme.pastelRed
                              : AppTheme.pastelGreen));
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
                      child: Icon(icon, size: 18, color: iconColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description != null && tx.description!.isNotEmpty
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
                          fontWeight: isSavings
                              ? FontWeight.w700
                              : FontWeight.w600,
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

  void _openAddTransaction(
    BuildContext context,
    TransactionType type, {
    String? initialCategoryId,
    int? initialAmount,
  }) {
    showAddTransaction(
      context,
      type: type,
      categoryId: initialCategoryId,
      amount: initialAmount,
    );
  }

  Future<void> _openPeriodPicker(BuildContext context) async {
    final picked = await showPeriodPicker(
      context,
      ref.read(selectedPeriodProvider),
    );
    if (picked != null) {
      ref.read(selectedPeriodProvider.notifier).state = picked;
    }
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
