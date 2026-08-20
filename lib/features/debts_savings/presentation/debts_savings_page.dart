// lib/features/debts_savings/presentation/debts_savings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive_center.dart';
import '../domain/debt.dart';
import '../domain/savings_goal.dart';
import 'providers/debts_savings_provider.dart';
import 'widgets/add_debt_dialog.dart';
import 'widgets/add_savings_goal_dialog.dart';
import 'widgets/record_payment_dialog.dart';
import 'widgets/record_savings_dialog.dart';

class DebtsSavingsPage extends ConsumerStatefulWidget {
  const DebtsSavingsPage({super.key});

  @override
  ConsumerState<DebtsSavingsPage> createState() => _DebtsSavingsPageState();
}

class _DebtsSavingsPageState extends ConsumerState<DebtsSavingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savingsAsync = ref.watch(savingsGoalsProvider);
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Target & Utang',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
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
            tooltip: 'Tambah Item',
            onPressed: () {
              if (_tabCtrl.index == 0) {
                _openAddSavingsGoal(context);
              } else {
                _openAddDebt(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDarkMuted,
          labelStyle:
              GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Tabungan & Dana Darurat'),
            Tab(text: 'Utang & Cicilan'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Tab 1: Savings & Emergency Fund ──────────────────────────────
            _buildSavingsTab(savingsAsync),

            // ── Tab 2: Debts & Paylater ───────────────────────────────────────
            _buildDebtsTab(debtsAsync),
          ],
        ),
      ),
    );
  }

  // ─── Tab 1: Savings Goals (Style Matching Reference Image: "Education 52%") ─
  Widget _buildSavingsTab(AsyncValue<List<SavingsGoal>> savingsAsync) {
    return savingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.savings_outlined,
            title: 'Belum Ada Target Tabungan',
            description:
                'Tetapkan target Dana Darurat atau tabungan impian untuk mengamankan masa depanmu.',
            actionLabel: 'Buat Target Baru',
            onAction: () => _openAddSavingsGoal(context),
          );
        }

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: goals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final goal = goals[i];
              final pct = (goal.progressPercentage * 100).toStringAsFixed(0);
              final isEmergency = goal.goalType == GoalType.emergencyFund;

              return CloudPulseCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Circle Icon + Name/Status + Target Amount
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isEmergency
                                ? AppTheme.pastelBlue
                                : AppTheme.pastelGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEmergency
                                ? Icons.shield_outlined
                                : Icons.savings_outlined,
                            size: 22,
                            color: isEmergency
                                ? AppTheme.primary
                                : AppTheme.tertiary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDarkPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$pct% dari target',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: isEmergency
                                      ? AppTheme.primary
                                      : AppTheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          goal.targetAmount.toRupiah,
                          style: AppTheme.monoCurrency(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goal.progressPercentage,
                        minHeight: 8,
                        backgroundColor: AppTheme.surfaceLightAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isEmergency ? AppTheme.primary : AppTheme.tertiary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom info & Action button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Terkumpul: ${goal.currentAmount.toRupiah}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textDarkSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _openRecordSavings(context, goal),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                          label: const Text('Setor / Tarik'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLightAlt,
                            foregroundColor: AppTheme.textDarkPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            textStyle: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── Tab 2: Debts & Loans ──────────────────────────────────────────────────
  Widget _buildDebtsTab(AsyncValue<List<Debt>> debtsAsync) {
    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (debts) {
        if (debts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.credit_card_outlined,
            title: 'Bebas Utang & Cicilan 🎉',
            description:
                'Tidak ada cicilan atau tagihan paylater yang tercatat saat ini.',
            actionLabel: 'Tambah Catatan Cicilan',
            onAction: () => _openAddDebt(context),
          );
        }

        return ResponsiveCenter(
          maxWidth: 800,
          padding: const EdgeInsets.all(16),
          child: ListView.separated(
            itemCount: debts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final debt = debts[i];
              final isPaid = debt.isPaid;
              final pct = (debt.paidPercentage * 100).toStringAsFixed(0);

              return CloudPulseCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppTheme.pastelGreen
                                : AppTheme.pastelRed,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaid
                                ? Icons.check_circle_outline_rounded
                                : Icons.credit_card_rounded,
                            size: 22,
                            color: isPaid ? AppTheme.success : AppTheme.danger,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDarkPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPaid ? 'LUNAS 🎉' : '$pct% terbayar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: isPaid
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          debt.totalAmount.toRupiah,
                          style: AppTheme.monoCurrency(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: debt.paidPercentage,
                        minHeight: 8,
                        backgroundColor: AppTheme.surfaceLightAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPaid ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isPaid
                                ? 'Semua cicilan lunas'
                                : 'Sisa Utang: ${debt.remainingAmount.toRupiah}',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: isPaid
                                  ? AppTheme.success
                                  : AppTheme.textDarkSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isPaid) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () =>
                                _openRecordPayment(context, debt),
                            icon: const Icon(Icons.payment_rounded, size: 14),
                            label: const Text('Bayar Cicilan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceLightAlt,
                              foregroundColor: AppTheme.textDarkPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              textStyle: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _openAddSavingsGoal(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddSavingsGoalDialog(),
    );
  }

  void _openRecordSavings(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (_) => RecordSavingsDialog(goal: goal),
    );
  }

  void _openAddDebt(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AddDebtDialog(),
    );
  }

  void _openRecordPayment(BuildContext context, Debt debt) {
    showDialog(
      context: context,
      builder: (_) => RecordPaymentDialog(debt: debt),
    );
  }
}
