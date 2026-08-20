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
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDarkMuted,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14),
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
            // ── Tab 1: Savings Goals ──────────────────────────────────────
            _buildSavingsTab(savingsAsync),

            // ── Tab 2: Debts ──────────────────────────────────────────────
            _buildDebtsTab(debtsAsync),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabCtrl.index == 0) {
            _openAddSavingsGoal(context);
          } else {
            _openAddDebt(context);
          }
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabCtrl.index == 0 ? 'Tambah Target' : 'Tambah Utang',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSavingsTab(AsyncValue<List<SavingsGoal>> savingsAsync) {
    return savingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.savings_rounded,
            title: 'Belum Ada Target Tabungan',
            description:
                'Buat target Dana Darurat atau tabungan impian untuk melihat progress finansialmu.',
            actionLabel: 'Buat Target Tabungan',
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
              final isEmergency = goal.goalType == GoalType.emergencyFund;

              return CloudPulseCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isEmergency
                                ? AppTheme.tertiary.withValues(alpha: 0.15)
                                : AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Icon(
                            isEmergency
                                ? Icons.health_and_safety_rounded
                                : Icons.savings_outlined,
                            size: 20,
                            color: isEmergency
                                ? AppTheme.tertiary
                                : AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goal.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDarkPrimary,
                                ),
                              ),
                              Text(
                                goal.goalType.displayName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(goal.progressPercentage * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: goal.isCompleted
                                ? AppTheme.success
                                : AppTheme.primary,
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
                        minHeight: 6,
                        backgroundColor: AppTheme.surfaceDarkAlt,
                        valueColor: AlwaysStoppedAnimation(
                          goal.isCompleted ? AppTheme.success : AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${goal.currentAmount.toRupiah} / ${goal.targetAmount.toRupiah}',
                            style: AppTheme.monoCurrency(
                              fontSize: 13,
                              color: AppTheme.textDarkSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _openRecordSavings(context, goal),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(90, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            side: const BorderSide(color: AppTheme.tertiary),
                            foregroundColor: AppTheme.tertiary,
                          ),
                          child: const Text('Setor / Tarik'),
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

  Widget _buildDebtsTab(AsyncValue<List<Debt>> debtsAsync) {
    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (debts) {
        if (debts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.credit_score_rounded,
            title: 'Bebas Utang! 🎉',
            description:
                'Tidak ada catatan utang aktif. Catat cicilan atau paylater jika ingin melacak pelunasannya.',
            actionLabel: 'Tambah Catatan Utang',
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

              return CloudPulseCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: debt.isPaid
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: Icon(
                            debt.isPaid
                                ? Icons.check_circle_outline_rounded
                                : Icons.credit_card_rounded,
                            size: 20,
                            color: debt.isPaid ? AppTheme.success : AppTheme.danger,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                debt.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDarkPrimary,
                                ),
                              ),
                              Text(
                                '${debt.debtType.displayName}${debt.dueDay != null ? ' • Tempo tgl ${debt.dueDay}' : ''}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (debt.isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LUNAS',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          )
                        else
                          Text(
                            debt.remainingAmount.toRupiah,
                            style: AppTheme.monoCurrency(
                              color: AppTheme.danger,
                              fontSize: 15,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Progress Bar of Payoff
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: debt.paidPercentage,
                        minHeight: 6,
                        backgroundColor: AppTheme.surfaceDarkAlt,
                        valueColor: AlwaysStoppedAnimation(
                          debt.isPaid ? AppTheme.success : AppTheme.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Terbayar: ${debt.paidAmount.toRupiah} (${(debt.paidPercentage * 100).toStringAsFixed(0)}%)',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textDarkSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!debt.isPaid)
                          ElevatedButton(
                            onPressed: () => _openRecordPayment(context, debt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.danger,
                              minimumSize: const Size(90, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text('Bayar'),
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

  void _openAddSavingsGoal(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddSavingsGoalDialog());
  }

  void _openAddDebt(BuildContext context) {
    showDialog(context: context, builder: (_) => const AddDebtDialog());
  }

  void _openRecordSavings(BuildContext context, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (_) => RecordSavingsDialog(goal: goal),
    );
  }

  void _openRecordPayment(BuildContext context, Debt debt) {
    showDialog(
      context: context,
      builder: (_) => RecordPaymentDialog(debt: debt),
    );
  }
}
