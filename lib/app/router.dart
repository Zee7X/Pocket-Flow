// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_shell.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/categories_rules/presentation/categories_rules_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/debts_savings/presentation/debts_savings_page.dart';
import '../features/reports/presentation/monthly_reports_page.dart';
import '../features/salary_allocation/presentation/salary_allocation_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/capture/presentation/capture_link_page.dart';
import '../features/capture/presentation/capture_settings_page.dart';
import '../features/capture/presentation/inbox_page.dart';
import '../features/import/presentation/import_page.dart';
import '../features/more/more_page.dart';
import '../features/recurring/presentation/recurring_page.dart';
import '../features/splits/presentation/splits_page.dart';
import '../features/wallets/presentation/wallets_page.dart';

// Route name constants
class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/';
  static const salary = '/salary';
  static const transactions = '/transactions';
  static const debtsSavings = '/debts-savings';
  static const categoriesRules = '/categories-rules';
  static const reports = '/reports';
  static const inbox = '/inbox';
  static const captureSettings = '/capture-settings';
  static const captureLink = '/capture';
  static const wallets = '/wallets';
  static const bills = '/bills';
  static const splits = '/splits';
  static const import = '/import';
  static const more = '/more';
}

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLoggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (isSplash) {
        return null;
      }
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      // ── Splash Route ───────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),

      // ── Auth Routes ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (context, state) => const MonthlyReportsPage(),
      ),
      GoRoute(path: AppRoutes.inbox, builder: (_, _) => const InboxPage()),
      GoRoute(path: AppRoutes.captureSettings, builder: (_, _) => const CaptureSettingsPage()),
      GoRoute(
        path: AppRoutes.captureLink,
        builder: (_, state) => CaptureLinkPage(query: state.uri.queryParameters),
      ),
      GoRoute(path: AppRoutes.wallets, builder: (_, _) => const WalletsPage()),
      GoRoute(path: AppRoutes.bills, builder: (_, _) => const RecurringPage()),
      GoRoute(path: AppRoutes.splits, builder: (_, _) => const SplitsPage()),
      GoRoute(path: AppRoutes.import, builder: (_, _) => const ImportPage()),
      GoRoute(path: AppRoutes.more, builder: (_, _) => const MorePage()),

      // ── Main App Shell with Bottom Navigation ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: 'dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),

          // Branch 1: Alokasi Gaji (Salary Engine)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.salary,
                name: 'salary',
                builder: (context, state) => const SalaryAllocationPage(),
              ),
            ],
          ),

          // Branch 2: Transaksi
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                name: 'transactions',
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),

          // Branch 3: Target & Utang
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.debtsSavings,
                name: 'debtsSavings',
                builder: (context, state) => const DebtsSavingsPage(),
              ),
            ],
          ),

          // Branch 4: Aturan & Kategori
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.categoriesRules,
                name: 'categoriesRules',
                builder: (context, state) => const CategoriesRulesPage(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

/// Listenable that triggers GoRouter refresh when auth state changes.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authProvider, (_, _) => notifyListeners());
  }
}
