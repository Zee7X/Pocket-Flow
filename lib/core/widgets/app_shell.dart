// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter/services.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../features/transactions/domain/transaction.dart';
import '../../features/transactions/presentation/widgets/add_transaction_dialog.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Jika sedang di tab selain Home, slide back akan kembali ke Home lebih dulu
        if (widget.navigationShell.currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          return;
        }

        // 2. Jika sudah di Home, tampilkan peringatan double-back agar tidak tertutup tidak sengaja
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Slide sekali lagi untuk keluar dari aplikasi',
                    style: GoogleFonts.dmSans(
                        color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
              backgroundColor:
                  AppTheme.textDarkPrimary.withValues(alpha: 0.92),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMedium),
              ),
              margin: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
            ),
          );
          return;
        }

        // Keluar dari aplikasi jika slide back 2x berturut-turut dalam 2 detik
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppTheme.canvasLight,
        body: widget.navigationShell,
        floatingActionButton: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.heroGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(29),
              onTap: () => _openQuickAddModal(context),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: AppTheme.surfaceLight,
          elevation: 10,
          surfaceTintColor: Colors.transparent,
          shadowColor:
              const Color(0xFF0F172A).withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left 2 items
              Row(
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                  ),
                  const SizedBox(width: 6),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.receipt_long_rounded,
                    label: 'Transaksi',
                    isSelected: currentIndex == 2,
                  ),
                ],
              ),

              // Middle space for floating + button
              const SizedBox(width: 48),

              // Right 2 items
              Row(
                children: [
                  _buildNavItem(
                    context,
                    index: 1,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Alokasi',
                    isSelected: currentIndex == 1,
                  ),
                  const SizedBox(width: 6),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.savings_rounded,
                    label: 'Target',
                    isSelected: currentIndex == 3,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: () {
        widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.textDarkSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? AppTheme.primary : AppTheme.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickAddModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: false,
      barrierColor: const Color(0x73000000),
      backgroundColor: AppTheme.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Aksi Cepat PocketFlow',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDarkPrimary,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_outward_rounded,
                      color: AppTheme.danger, size: 20),
                ),
                title: Text(
                  'Catat Pengeluaran',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                subtitle: Text(
                  'Catat belanja atau tagihan harian',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppTheme.textDarkSecondary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textDarkMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => const AddTransactionDialog(
                      initialType: TransactionType.expense,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward_rounded,
                      color: AppTheme.success, size: 20),
                ),
                title: Text(
                  'Catat Pemasukan',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                subtitle: Text(
                  'Catat bonus, freelance, atau pemasukan lain',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppTheme.textDarkSecondary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textDarkMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => const AddTransactionDialog(
                      initialType: TransactionType.income,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.pastelBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                title: Text(
                  'Input Alokasi Gaji',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textDarkPrimary,
                  ),
                ),
                subtitle: Text(
                  'Kunci dan alokasikan gaji bulanan',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, color: AppTheme.textDarkSecondary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textDarkMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.salary);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
