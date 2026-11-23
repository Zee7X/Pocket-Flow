// lib/core/widgets/app_shell.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../features/alerts/budget_alerts.dart';
import '../../features/capture/presentation/providers/capture_provider.dart';
import '../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../features/smart/presentation/smart_input_sheet.dart';
import '../../features/splits/presentation/splits_page.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/presentation/widgets/add_transaction_dialog.dart';
import '../../features/wallets/presentation/wallets_page.dart';
import 'app_modal.dart';
import 'ui.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  DateTime? _lastBackPressTime;
  StreamSubscription<void>? _capturedSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final channel = ref.read(captureChannelProvider);
    if (channel.isSupported) {
      _capturedSub = channel.onCaptured.listen((_) => _drainCaptured());
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Sinkronkan daftar aplikasi yang dibaca ke layanan native.
        await channel.setAllowedPackages(
          ref.read(captureSettingsProvider).allowedPackages,
        );
        _drainCaptured();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _capturedSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _drainCaptured();
  }

  Future<void> _drainCaptured() async {
    try {
      await ref.read(pendingCapturesProvider.notifier).drainNative();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // Peringatan budget real-time sebagai snackbar.
    ref.listen<BudgetAlert?>(lastBudgetAlertProvider, (_, alert) {
      if (alert == null) return;
      alert.percent >= 100
          ? AppTheme.showErrorSnackBar(context, alert.message)
          : AppTheme.showSuccessSnackBar(context, alert.message);
      ref.read(lastBudgetAlertProvider.notifier).state = null;
    });

    // Data widget layar utama Android ("Sisa aman hari ini").
    ref.listen<AsyncValue<DashboardSummary>>(dashboardSummaryProvider, (
      _,
      next,
    ) {
      final s = next.value;
      if (s == null) return;
      ref
          .read(captureChannelProvider)
          .updateWidget(
            safeToday: s.safeSpendingToday,
            spentToday: s.totalSpentToday,
            dailyQuota: s.dailyQuotaToday,
          );
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tekan kembali sekali lagi untuk keluar',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
              backgroundColor: AppTheme.textDarkPrimary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          );
          return;
        }
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.canvasLight,
        body: widget.navigationShell,
        floatingActionButton: SizedBox(
          width: 56,
          height: 56,
          child: FloatingActionButton(
            heroTag: 'shell-add',
            tooltip: 'Catat',
            onPressed: () => openQuickAddModal(context),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            highlightElevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          color: AppTheme.surfaceLight,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          height: 64,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Ui.border)),
            ),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => _go(0),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Transaksi',
                  selected: currentIndex == 2,
                  onTap: () => _go(2),
                ),
                const SizedBox(width: 64),
                _NavItem(
                  icon: Icons.pie_chart_outline_rounded,
                  activeIcon: Icons.pie_chart_rounded,
                  label: 'Alokasi',
                  selected: currentIndex == 1,
                  onTap: () => _go(1),
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  activeIcon: Icons.flag_rounded,
                  label: 'Target',
                  selected: currentIndex == 3,
                  onTap: () => _go(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.textDarkSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 23, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu aksi cepat dari tombol +.
void openQuickAddModal(BuildContext context) {
  showAppModal<void>(
    context: context,
    builder: (ctx) {
      void then(VoidCallback action) {
        Navigator.of(ctx).pop();
        // Tunggu sheet tertutup supaya modal berikutnya tidak menumpuk.
        Future.delayed(const Duration(milliseconds: 220), action);
      }

      Widget item(
        IconData icon,
        Color color,
        String title,
        String sub,
        VoidCallback onTap,
      ) => ListRow(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        leading: IconBadge(icon, color: color, size: 40),
        title: title,
        subtitle: sub,
        onTap: () => then(onTap),
      );

      return AppModalScaffold(
        title: 'Catat',
        bodyPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            item(
              Icons.auto_awesome_outlined,
              AppTheme.primary,
              'Catat pintar',
              'Ketik atau ucapkan, mis. "kopi 18rb pakai gopay"',
              () => showSmartInputSheet(context),
            ),
            item(
              Icons.receipt_long_outlined,
              AppTheme.primary,
              'Scan struk',
              'Foto struk atau screenshot bukti bayar',
              () =>
                  showSmartInputSheet(context, start: SmartInputStart.receipt),
            ),
            const Divider(height: 16),
            item(
              Icons.north_east_rounded,
              AppTheme.textDarkSecondary,
              'Pengeluaran',
              'Isi form manual',
              () => showAddTransaction(context, type: TransactionType.expense),
            ),
            item(
              Icons.south_west_rounded,
              const Color(0xFF059669),
              'Pemasukan',
              'Gaji, bonus, freelance, dan lainnya',
              () => showAddTransaction(context, type: TransactionType.income),
            ),
            item(
              Icons.swap_horiz_rounded,
              AppTheme.primary,
              'Transfer antar dompet',
              'Top up, tarik tunai, pindah saldo',
              () => showTransferSheet(context),
            ),
            item(
              Icons.groups_outlined,
              AppTheme.primary,
              'Patungan',
              'Bayarin teman dulu, catat piutangnya',
              () => showSplitSheet(context),
            ),
            item(
              Icons.account_balance_wallet_outlined,
              AppTheme.primary,
              'Alokasi gaji',
              'Bagi gaji ke pos-pos bulanan',
              () => context.go(AppRoutes.salary),
            ),
          ],
        ),
      );
    },
  );
}
