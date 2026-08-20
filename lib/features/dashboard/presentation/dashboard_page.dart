// lib/features/dashboard/presentation/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final period = ref.watch(selectedPeriodProvider);

    final String greetingName = switch (authState) {
      domain.AuthAuthenticated(:final email) =>
        email != null ? email.split('@').first : 'User',
      _ => 'User',
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, $greetingName 👋',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkPrimary,
              ),
            ),
            Text(
              _getCurrentPeriod(period),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.textDarkMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            maxWidth: 800,
            padding: const EdgeInsets.all(20),
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
                    // ── 1. Hero Safe Spending Today Card ───────────────────
                    _buildSafeSpendingCard(context, summary),

                    const SizedBox(height: 18),

                    // ── 2. Quick Overview Cards ────────────────────────────
                    _buildOverviewRow(summary),

                    const SizedBox(height: 20),

                    // ── 3. Quick Action Buttons ────────────────────────────
                    _buildQuickActions(context),

                    const SizedBox(height: 24),

                    // ── 4. Budget per Kategori ─────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Budget Kategori Bulan Ini',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.salary),
                          child: const Text('Atur Gaji'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildCategoryBudgetList(context, summary.categoryBudgets),

                    const SizedBox(height: 24),

                    // ── 5. Transaksi Terakhir ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Transaksi Terkini',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDarkPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.transactions),
                          child: const Text('Lihat Semua'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecentTransactions(context, summary.recentTransactions),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeSpendingCard(BuildContext context, DashboardSummary summary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withValues(alpha: 0.22),
            AppTheme.secondary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Safe Spending Hari Ini',
                      style: GoogleFonts.dmSans(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Sisa ${summary.daysRemainingInMonth} hari',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textDarkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary.safeSpendingToday.toRupiah,
            style: AppTheme.monoCurrency(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDarkPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Maksimal pengeluaran aman hari ini agar budget bulanan tetap terkontrol.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textDarkSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow(DashboardSummary summary) {
    return Row(
      children: [
        Expanded(
          child: CloudPulseCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Budget',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textDarkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.totalAllocated.toRupiahCompact,
                  style: AppTheme.monoCurrency(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CloudPulseCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terpakai',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textDarkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.totalSpent.toRupiahCompact,
                  style: AppTheme.monoCurrency(
                    fontSize: 15,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: CloudPulseCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sisa Uang',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.textDarkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.remainingBudget.toRupiahCompact,
                  style: AppTheme.monoCurrency(
                    fontSize: 15,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AddTransactionDialog(),
              );
            },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
            label: const Text('Catat Pengeluaran'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.salary),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Alokasi Gaji'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 42),
              side: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBudgetList(
      BuildContext context, List<MonthlyBudget> budgets) {
    if (budgets.isEmpty) {
      return CloudPulseCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada alokasi budget untuk bulan ini. Masukkan gaji di menu Alokasi Gaji.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textDarkSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: budgets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final b = budgets[i];
        return CloudPulseCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      b.categoryName ?? 'Kategori',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${b.spentAmount.toRupiah} / ${b.allocatedAmount.toRupiah}',
                    style: AppTheme.monoCurrency(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: b.spentPercentage,
                  minHeight: 5,
                  backgroundColor: AppTheme.surfaceDarkAlt,
                  valueColor: AlwaysStoppedAnimation(
                    b.isOverBudget ? AppTheme.danger : AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context, List<TransactionModel> transactions) {
    if (transactions.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long_rounded,
        title: 'Belum Ada Transaksi Bulan Ini',
        description: 'Setiap pengeluaran yang dicatat akan muncul di sini.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tx = transactions[i];
        final isExpense = tx.type == TransactionType.expense;

        return CloudPulseCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description ?? tx.categoryName ?? 'Transaksi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                  if (tx.categoryName != null)
                    Text(
                      tx.categoryName!,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.textDarkMuted,
                      ),
                    ),
                ],
              ),
              Text(
                '${isExpense ? '-' : '+'}${tx.amount.toRupiah}',
                style: AppTheme.monoCurrency(
                  color: isExpense ? AppTheme.danger : AppTheme.success,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
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
