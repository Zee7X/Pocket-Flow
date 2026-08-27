// lib/features/debts_savings/presentation/debts_savings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/widgets/cloudpulse_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
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
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textDarkMuted,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
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
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () async {
          ref.invalidate(savingsGoalsProvider);
        },
      ),
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
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
                                isEmergency ? 'Dana Darurat' : 'Target Tabungan',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Target',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                              Text(
                                goal.targetAmount.toRupiah,
                                style: AppTheme.monoCurrency(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDarkPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress Header with Prominent Percentage Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Progress Terkumpul',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textDarkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEmergency
                                ? AppTheme.pastelBlue
                                : AppTheme.pastelGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pct% Tercapai',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isEmergency
                                  ? AppTheme.primary
                                  : AppTheme.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: goal.progressPercentage,
                        minHeight: 10,
                        backgroundColor: AppTheme.surfaceLightAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isEmergency ? AppTheme.primary : AppTheme.tertiary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom info & Action button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo Terkumpul:',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                              Text(
                                goal.currentAmount.toRupiah,
                                style: AppTheme.monoCurrency(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isEmergency
                                      ? AppTheme.primary
                                      : AppTheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _openRecordSavings(context, goal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLightAlt,
                            foregroundColor: AppTheme.textDarkPrimary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz_rounded, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Setor / Tarik',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppTheme.textDarkMuted),
                          tooltip: 'Hapus Target',
                          onPressed: () => _deleteGoal(goal),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
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
      error: (e, _) => AppErrorWidget(
        error: e,
        onRetry: () async {
          ref.invalidate(debtsProvider);
        },
      ),
      data: (debts) {
        if (debts.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.credit_card_off_rounded,
            title: 'Tidak Ada Catatan Utang',
            description: 'Bagus! Catat cicilan atau pinjaman jika ada untuk memantau pelunasan.',
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
              final isPaid = debt.isPaid;
              final pct = (debt.paidPercentage * 100).toInt();

              return CloudPulseCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppTheme.pastelGreen
                                : AppTheme.pastelYellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaid
                                ? Icons.check_circle_outline_rounded
                                : Icons.credit_card_outlined,
                            size: 22,
                            color: isPaid ? AppTheme.success : AppTheme.warning,
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
                              ),
                              const SizedBox(height: 2),
                              Text(
                                debt.debtType.displayName,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Total Pokok',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                              Text(
                                debt.totalAmount.toRupiah,
                                style: AppTheme.monoCurrency(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textDarkPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Progress Header with Prominent Percentage Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isPaid ? 'Status Pelunasan' : 'Progress Terbayar',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: AppTheme.textDarkSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? AppTheme.pastelGreen
                                : AppTheme.pastelYellow,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPaid ? '100% Lunas' : '$pct% Terbayar',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isPaid
                                  ? AppTheme.success
                                  : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: debt.paidPercentage,
                        minHeight: 10,
                        backgroundColor: AppTheme.surfaceLightAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPaid ? AppTheme.success : AppTheme.warning,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isPaid ? 'Status:' : 'Sisa Utang:',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppTheme.textDarkMuted,
                                ),
                              ),
                              Text(
                                isPaid
                                    ? 'Semua Lunas'
                                    : debt.remainingAmount.toRupiah,
                                style: AppTheme.monoCurrency(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isPaid
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isPaid) ...[
                          ElevatedButton(
                            onPressed: () =>
                                _openRecordPayment(context, debt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceLightAlt,
                              foregroundColor: AppTheme.textDarkPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.payment_rounded, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Bayar',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AppTheme.textDarkMuted),
                          tooltip: 'Hapus Utang',
                          onPressed: () => _deleteDebt(debt),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: EdgeInsets.zero,
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

  Future<void> _deleteGoal(SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          side: const BorderSide(color: AppTheme.borderLightSubtle),
        ),
        title: Text(
          'Hapus Target Tabungan?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus target "${goal.name}"?',
          style: GoogleFonts.dmSans(
            color: AppTheme.textDarkSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(savingsGoalsProvider.notifier).deleteSavingsGoal(goal.id);
        if (mounted) {
          AppTheme.showSuccessSnackBar(
            context,
            'Target tabungan "${goal.name}" berhasil dihapus.',
          );
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showErrorSnackBar(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
  }

  Future<void> _deleteDebt(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          side: const BorderSide(color: AppTheme.borderLightSubtle),
        ),
        title: Text(
          'Hapus Catatan Utang?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus catatan utang "${debt.name}"?',
          style: GoogleFonts.dmSans(
            color: AppTheme.textDarkSecondary,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(debtsProvider.notifier).deleteDebt(debt.id);
        if (mounted) {
          AppTheme.showSuccessSnackBar(
            context,
            'Catatan utang "${debt.name}" berhasil dihapus.',
          );
        }
      } catch (e) {
        if (mounted) {
          AppTheme.showErrorSnackBar(
            context,
            e.toString().replaceAll('Exception: ', ''),
          );
        }
      }
    }
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
