// lib/app/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_shell.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/categories_rules/presentation/categories_rules_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/debts_savings/presentation/debts_savings_page.dart';
import '../features/salary_allocation/presentation/salary_allocation_page.dart';
import '../features/transactions/presentation/transactions_page.dart';

// Route name constants
class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/';
  static const salary = '/salary';
  static const transactions = '/transactions';
  static const debtsSavings = '/debts-savings';
  static const categoriesRules = '/categories-rules';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;

      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
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
