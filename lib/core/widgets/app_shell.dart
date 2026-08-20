// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(
            top: BorderSide(color: AppTheme.borderDark, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          backgroundColor: Colors.transparent,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textDarkMuted,
          selectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded, size: 22),
              activeIcon: Icon(Icons.dashboard_rounded, size: 24),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_rounded, size: 22),
              activeIcon: Icon(Icons.account_balance_rounded, size: 24),
              label: 'Alokasi Gaji',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded, size: 22),
              activeIcon: Icon(Icons.receipt_long_rounded, size: 24),
              label: 'Transaksi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.savings_rounded, size: 22),
              activeIcon: Icon(Icons.savings_rounded, size: 24),
              label: 'Target',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_rounded, size: 22),
              activeIcon: Icon(Icons.tune_rounded, size: 24),
              label: 'Aturan',
            ),
          ],
        ),
      ),
    );
  }
}
