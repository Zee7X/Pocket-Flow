// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pocket_flow/app/theme.dart';
import 'package:pocket_flow/features/auth/domain/auth_state.dart' as domain;
import 'package:pocket_flow/features/auth/presentation/login_page.dart';
import 'package:pocket_flow/features/auth/presentation/register_page.dart';
import 'package:pocket_flow/features/auth/presentation/providers/auth_provider.dart';
import 'package:pocket_flow/features/categories_rules/domain/allocation_rule.dart';
import 'package:pocket_flow/features/categories_rules/domain/category.dart';
import 'package:pocket_flow/features/categories_rules/presentation/categories_rules_page.dart';
import 'package:pocket_flow/features/categories_rules/presentation/providers/categories_rules_provider.dart';
import 'package:pocket_flow/features/dashboard/presentation/dashboard_page.dart';
import 'package:pocket_flow/features/debts_savings/domain/debt.dart';
import 'package:pocket_flow/features/debts_savings/domain/savings_goal.dart';
import 'package:pocket_flow/features/debts_savings/presentation/debts_savings_page.dart';
import 'package:pocket_flow/features/debts_savings/presentation/providers/debts_savings_provider.dart';
import 'package:pocket_flow/features/reports/domain/monthly_report.dart';
import 'package:pocket_flow/features/reports/presentation/monthly_reports_page.dart';
import 'package:pocket_flow/features/reports/presentation/providers/reports_provider.dart';
import 'package:pocket_flow/features/salary_allocation/data/salary_repository.dart';
import 'package:pocket_flow/features/salary_allocation/domain/monthly_budget.dart';
import 'package:pocket_flow/features/salary_allocation/domain/salary_allocation_result.dart';
import 'package:pocket_flow/features/salary_allocation/domain/salary_entry.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/salary_allocation_page.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';
import 'package:pocket_flow/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:pocket_flow/features/transactions/presentation/transactions_page.dart';
import 'package:pocket_flow/features/categories_rules/presentation/widgets/add_rule_dialog.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/widgets/allocation_preview_sheet.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/widgets/salary_history_detail_sheet.dart';
import 'package:pocket_flow/features/transactions/presentation/widgets/add_transaction_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthNotifier extends AuthNotifier {
  final domain.AuthState initialState;
  MockAuthNotifier([this.initialState = const domain.AuthUnauthenticated()]);

  @override
  domain.AuthState build() => initialState;

  @override
  Future<void> signIn({required String email, required String password}) async {}

  @override
  Future<void> signUp({required String email, required String password, String? name}) async {}

  @override
  Future<void> signOut() async {
    state = const domain.AuthUnauthenticated();
  }
}

class MockSalaryRepository extends SalaryRepository {
  MockSalaryRepository()
      : super(SupabaseClient(
          'https://mock.supabase.co',
          'mock-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<SalaryAllocationResult> previewAllocation({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    return SalaryAllocationResult(
      success: true,
      salaryAmount: salaryAmount,
      totalAllocated: salaryAmount,
      periodMonth: periodMonth,
      periodYear: periodYear,
      remaining: 0,
      allocations: [],
      warnings: [],
    );
  }

  @override
  Future<SalaryAllocationResult> allocateSalary({
    required int salaryAmount,
    required DateTime salaryDate,
    required int periodMonth,
    required int periodYear,
  }) async {
    return SalaryAllocationResult(
      success: true,
      salaryAmount: salaryAmount,
      totalAllocated: salaryAmount,
      periodMonth: periodMonth,
      periodYear: periodYear,
      remaining: 0,
      allocations: [],
      warnings: [],
    );
  }
}

Widget createTestApp(
  Widget child, {
  domain.AuthState? authState,
  Size? screenSize,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        () => MockAuthNotifier(
          authState ??
              const domain.AuthAuthenticated(
                userId: 'test-user',
                email: 'test@pocketflow.com',
              ),
        ),
      ),
      salaryRepositoryProvider.overrideWithValue(MockSalaryRepository()),
      monthlyBudgetsProvider.overrideWith((ref) async => [
            const MonthlyBudget(
              id: 'b1',
              userId: 'test-user',
              categoryId: 'c1',
              periodMonth: 8,
              periodYear: 2026,
              allocatedAmount: 1000000,
              spentAmount: 250000,
              categoryName: 'Makan',
            ),
            const MonthlyBudget(
              id: 'b2',
              userId: 'test-user',
              categoryId: 'c2',
              periodMonth: 8,
              periodYear: 2026,
              allocatedAmount: 850000,
              spentAmount: 850000,
              categoryName: 'Sewa Kos',
            ),
          ]),
      transactionsProvider.overrideWith(() => _MockTransactionsNotifier()),
      salaryHistoryProvider.overrideWith((ref) async => [
            SalaryEntry(
              id: 's1',
              userId: 'test-user',
              amount: 5000000,
              salaryDate: DateTime(2026, 8, 25),
              periodMonth: 8,
              periodYear: 2026,
              createdAt: DateTime(2026, 8, 25),
            ),
          ]),
      categoriesProvider.overrideWith(() => _MockCategoriesNotifier()),
      allocationRulesProvider.overrideWith(() => _MockRulesNotifier()),
      debtsProvider.overrideWith(() => _MockDebtsNotifier()),
      savingsGoalsProvider.overrideWith(() => _MockSavingsNotifier()),
      monthlyReportProvider.overrideWith((ref) async => const MonthlyReport(
            month: 8,
            year: 2026,
            totalIncome: 5000000,
            totalExpense: 1100000,
            totalSavings: 1000000,
            totalDebtPayment: 400000,
            netCashFlow: 3500000,
            savingsRate: 20.0,
            categoryBreakdown: [
              CategorySpendingSummary(
                categoryName: 'Makan',
                allocatedAmount: 1000000,
                spentAmount: 250000,
                percentageOfTotalSpent: 0.23,
              ),
              CategorySpendingSummary(
                categoryName: 'Sewa Kos',
                allocatedAmount: 850000,
                spentAmount: 850000,
                percentageOfTotalSpent: 0.77,
              ),
            ],
            rawBudgets: [],
          )),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize ?? const Size(390, 844),
        ),
        child: child,
      ),
    ),
  );
}

class _MockTransactionsNotifier extends TransactionsNotifier {
  @override
  Future<List<TransactionModel>> build() async {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 't1',
        userId: 'test-user',
        type: TransactionType.expense,
        amount: 50000,
        transactionDate: DateTime(2026, 8, 20),
        description: 'Makan siang',
        categoryName: 'Makan',
        createdAt: DateTime(2026, 8, 20),
      ),
      // Future-dated (scheduled) transaction two months ahead
      TransactionModel(
        id: 't2',
        userId: 'test-user',
        type: TransactionType.expense,
        amount: 350000,
        transactionDate: DateTime(now.year, now.month + 2, 5),
        description: 'Bayar Internet',
        categoryName: 'Internet',
        createdAt: now,
      ),
    ];
  }
}

class _MockCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async {
    return [
      Category(
        id: 'c1',
        userId: 'test-user',
        name: 'Makan',
        type: CategoryType.expense,
        createdAt: DateTime.now(),
      ),
      Category(
        id: 'c2',
        userId: 'test-user',
        name: 'Sewa Kos',
        type: CategoryType.expense,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class _MockRulesNotifier extends AllocationRulesNotifier {
  @override
  Future<List<AllocationRule>> build() async {
    return [
      const AllocationRule(
        id: 'r1',
        userId: 'test-user',
        categoryId: 'c2',
        name: 'Sewa Kos',
        allocationType: AllocationType.fixed,
        fixedAmount: 850000,
        priority: 1,
        isRequired: true,
      ),
      const AllocationRule(
        id: 'r2',
        userId: 'test-user',
        categoryId: 'c1',
        name: 'Makan',
        allocationType: AllocationType.percentage,
        percentage: 30,
        priority: 2,
      ),
    ];
  }
}

class _MockDebtsNotifier extends DebtsNotifier {
  @override
  Future<List<Debt>> build() async {
    return [
      Debt(
        id: 'd1',
        userId: 'test-user',
        name: 'SPayLater',
        debtType: DebtType.paylater,
        totalAmount: 1200000,
        remainingAmount: 400000,
        minimumPayment: 400000,
        dueDay: 25,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

class _MockSavingsNotifier extends SavingsGoalsNotifier {
  @override
  Future<List<SavingsGoal>> build() async {
    return [
      SavingsGoal(
        id: 'sg1',
        userId: 'test-user',
        name: 'Dana Darurat 3 Bulan',
        goalType: GoalType.emergencyFund,
        targetAmount: 10000000,
        currentAmount: 3500000,
        createdAt: DateTime.now(),
      ),
    ];
  }
}

void main() {
  group('Full End-to-End Smoke & Responsiveness Tests', () {
    testWidgets('1. LoginPage renders & responsive', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const LoginPage(),
        authState: const domain.AuthUnauthenticated(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Selamat datang\nkembali 👋'), findsOneWidget);
      expect(find.text('Masuk'), findsWidgets);
    });

    testWidgets('2. RegisterPage renders & responsive', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const RegisterPage(),
        authState: const domain.AuthUnauthenticated(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mulai atur alokasi\nkeuanganmu ✨'), findsOneWidget);
    });

    testWidgets('3. DashboardPage renders Safe Spending and Category Budgets (With Allocation Mode)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const DashboardPage()));
      await tester.pumpAndSettle();

      expect(find.text('Safe Spending Hari Ini'), findsOneWidget);
      expect(find.text('Budget Kategori Bulan Ini'), findsOneWidget);
      expect(find.text('Makan'), findsWidgets);
      expect(find.text('Sewa Kos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3B. DashboardPage renders Sisa Saldo Kas & Income/Expense (Without Allocation Mode)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const DashboardPage(),
        extraOverrides: [
          monthlyBudgetsProvider.overrideWith((ref) async => []),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Sisa Saldo Kas Bulan Ini'), findsOneWidget);
      expect(find.text('Total Pemasukan'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Ingin Budget Otomatis dari Gaji?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. SalaryAllocationPage renders salary input & history', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const SalaryAllocationPage()));
      await tester.pumpAndSettle();

      expect(find.text('Input Gajian Masuk'), findsOneWidget);
      expect(find.text('Preview Alokasi Otomatis'), findsOneWidget);
      expect(find.text('Riwayat Gajian & Alokasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. TransactionsPage renders transaction list & filter chips', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const TransactionsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Akan Datang'), findsOneWidget);
      expect(find.text('Makan siang'), findsOneWidget);
      // Future-dated transaction renders with the upcoming badge in its subtitle
      expect(find.textContaining('Akan Datang'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('5B. TransactionsPage upcoming filter shows only scheduled transactions', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const TransactionsPage()));
      await tester.pumpAndSettle();

      // Both actual & scheduled transactions visible by default
      expect(find.text('Makan siang'), findsOneWidget);
      // Scroll to ensure the Akan Datang chip is in view on standard mobile screen
      final upcomingChip = find.widgetWithText(ChoiceChip, 'Akan Datang');
      await tester.ensureVisible(upcomingChip);
      await tester.tap(upcomingChip);
      await tester.pumpAndSettle();

      // Only the future-dated transaction remains
      expect(find.text('Bayar Internet'), findsOneWidget);
      expect(find.text('Makan siang'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. DebtsSavingsPage renders targets & loans', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const DebtsSavingsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Tabungan & Dana Darurat'), findsOneWidget);
      expect(find.text('Utang & Cicilan'), findsOneWidget);
      expect(find.text('Dana Darurat 3 Bulan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. CategoriesRulesPage renders rules & categories', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const CategoriesRulesPage()));
      await tester.pumpAndSettle();

      expect(find.text('Aturan Alokasi'), findsOneWidget);
      expect(find.text('Daftar Kategori'), findsOneWidget);
      expect(find.text('Sewa Kos'), findsOneWidget);
      expect(find.text('Wajib'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8. Wide Screen Tablet/Desktop Responsiveness (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(
        const DashboardPage(),
        screenSize: const Size(1280, 800),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Safe Spending Hari Ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Keyboard Open on Mobile (Bottom Inset 340px) - LoginPage & RegisterPage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(createTestApp(
        const LoginPage(),
        authState: const domain.AuthUnauthenticated(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Keyboard Open on Mobile - Salary Allocation Page', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(createTestApp(const SalaryAllocationPage()));
      await tester.pumpAndSettle();

      expect(find.text('Input Gajian Masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('11. MonthlyReportsPage renders cash flow & savings rate', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const MonthlyReportsPage()));
      await tester.pumpAndSettle();

      expect(find.text('Laporan Keuangan'), findsOneWidget);
      expect(find.text('Arus Kas Bersih (Net Cash Flow)'), findsOneWidget);
      expect(find.text('Savings Rate'), findsOneWidget);
      expect(find.text('Rincian Pengeluaran per Kategori'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('12. Small Phone (320x568) - All Pages Responsive', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // LoginPage on small screen
      await tester.pumpWidget(createTestApp(
        const LoginPage(),
        authState: const domain.AuthUnauthenticated(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Dashboard on small screen
      await tester.pumpWidget(createTestApp(
        const DashboardPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // DebtsSavings on small screen
      await tester.pumpWidget(createTestApp(
        const DebtsSavingsPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Categories on small screen
      await tester.pumpWidget(createTestApp(
        const CategoriesRulesPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Transactions on small screen
      await tester.pumpWidget(createTestApp(
        const TransactionsPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Reports on small screen
      await tester.pumpWidget(createTestApp(
        const MonthlyReportsPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // SalaryAllocation on small screen
      await tester.pumpWidget(createTestApp(
        const SalaryAllocationPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. Large Phone (414x896) - All Pages Responsive', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Dashboard on large screen
      await tester.pumpWidget(createTestApp(
        const DashboardPage(),
        screenSize: const Size(414, 896),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // DebtsSavings with data on large screen
      await tester.pumpWidget(createTestApp(
        const DebtsSavingsPage(),
        screenSize: const Size(414, 896),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Categories on large screen
      await tester.pumpWidget(createTestApp(
        const CategoriesRulesPage(),
        screenSize: const Size(414, 896),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Reports on large screen
      await tester.pumpWidget(createTestApp(
        const MonthlyReportsPage(),
        screenSize: const Size(414, 896),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('14. Keyboard Open - DebtsSavings & Categories', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(createTestApp(const DebtsSavingsPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(const CategoriesRulesPage()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('15. Small Phone Keyboard Open (320x568 + 280px inset) - Critical Pages', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(createTestApp(
        const LoginPage(),
        authState: const domain.AuthUnauthenticated(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(
        const SalaryAllocationPage(),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('16. AddTransactionDialog renders & responsive on Small & Standard screens with Keyboard', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddTransactionDialog(),
            ),
            child: const Text('Open'),
          ),
        ),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Catat Transaksi'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. AddRuleDialog renders & responsive with Decimal Percentage & Keyboard', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      final testCat = Category(
        id: 'cat-zakat',
        userId: 'test-user',
        name: 'Zakat',
        type: CategoryType.expense,
        createdAt: DateTime(2026, 8, 20),
      );

      const testRule = AllocationRule(
        id: 'rule-zakat',
        userId: 'test-user',
        categoryId: 'cat-zakat',
        name: 'Zakat',
        allocationType: AllocationType.percentage,
        percentage: 2.5,
        percentageBase: PercentageBase.totalIncome,
      );

      await tester.pumpWidget(createTestApp(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AddRuleDialog(
                categories: [testCat],
                initialRule: testRule,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
        screenSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Atur Alokasi: Zakat'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '2,5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('18. AllocationPreviewSheet renders unallocated surplus remaining correctly without deficit warning', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final result = SalaryAllocationResult(
        success: true,
        salaryAmount: 7600000,
        totalAllocated: 5981200,
        periodMonth: 9,
        periodYear: 2026,
        remaining: 1618800,
        allocations: const [
          RuleAllocationItem(
            ruleId: 'r1',
            ruleName: 'Cicilan / Utang',
            categoryId: 'c1',
            allocationType: 'fixed',
            allocatedAmount: 2000000,
          ),
          RuleAllocationItem(
            ruleId: 'r2',
            ruleName: 'Makan',
            categoryId: 'c2',
            allocationType: 'capped',
            allocatedAmount: 1000000,
          ),
        ],
        warnings: const [
          AllocationWarning(
            code: 'UNALLOCATED_REMAINDER',
            message: 'Terdapat sisa gaji sebesar 1618800 yang belum teralokasi ke aturan manapun.',
            amount: 1618800,
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        Scaffold(
          body: AllocationPreviewSheet(
            result: result,
            onConfirm: () {},
          ),
        ),
        screenSize: const Size(390, 844),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Preview Alokasi'), findsOneWidget);
      expect(find.text('Sisa Uang Bebas'), findsOneWidget);
      expect(find.text('Rp1.618.800'), findsWidgets);
      expect(find.text('79% Terencana'), findsOneWidget);
      expect(find.text('21% Sisa Bebas'), findsOneWidget);
      expect(find.text('Sisa Gaji Bebas: Rp1.618.800'), findsOneWidget);
      expect(find.text('Uang Kurang'), findsNothing);
      expect(find.text('Peringatan Defisit Kebutuhan Wajib'), findsNothing);
      expect(find.text('Terapkan & Buat Budget Bulanan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('18B. AllocationPreviewSheet renders actual deficit when required rule has shortfall', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final result = SalaryAllocationResult(
        success: true,
        salaryAmount: 3000000,
        totalAllocated: 3000000,
        periodMonth: 9,
        periodYear: 2026,
        remaining: 0,
        allocations: const [
          RuleAllocationItem(
            ruleId: 'r1',
            ruleName: 'Cicilan Wajib',
            categoryId: 'c1',
            allocationType: 'fixed',
            allocatedAmount: 1500000,
          ),
        ],
        warnings: const [
          AllocationWarning(
            code: 'SHORTFALL',
            ruleName: 'Cicilan Wajib',
            shortfall: 500000,
            message: 'Gaji tidak cukup untuk pos wajib: Cicilan Wajib',
          ),
        ],
      );

      await tester.pumpWidget(createTestApp(
        Scaffold(
          body: AllocationPreviewSheet(
            result: result,
            onConfirm: () {},
          ),
        ),
        screenSize: const Size(390, 844),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Preview Alokasi'), findsOneWidget);
      expect(find.text('Defisit / Status'), findsOneWidget);
      expect(find.text('Uang Kurang'), findsOneWidget);
      expect(find.text('Perlu Penyesuaian'), findsOneWidget);
      expect(find.text('Peringatan Defisit Kebutuhan Wajib'), findsOneWidget);
      expect(find.text('Tetap Kunci & Terapkan Budget'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('19. SalaryHistoryDetailSheet renders history details without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final entry = SalaryEntry(
        id: 'sal-1',
        userId: 'test-user',
        amount: 5500000,
        salaryDate: DateTime(2026, 9, 1),
        periodMonth: 9,
        periodYear: 2026,
        createdAt: DateTime(2026, 9, 1),
      );

      await tester.pumpWidget(createTestApp(
        Scaffold(
          body: SalaryHistoryDetailSheet(
            entry: entry,
            onEditForm: () {},
          ),
        ),
        screenSize: const Size(360, 640),
      ));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('Teralokasi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('20. Ultra-Wide Desktop (1920x1080) & Tablet (768x1024) Responsiveness', (tester) async {
      // 1. Ultra-Wide Desktop (1920x1080)
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestApp(
        const DashboardPage(),
        screenSize: const Size(1920, 1080),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(
        const TransactionsPage(),
        screenSize: const Size(1920, 1080),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 2. Tablet (768x1024)
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(createTestApp(
        const MonthlyReportsPage(),
        screenSize: const Size(768, 1024),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(createTestApp(
        const CategoriesRulesPage(),
        screenSize: const Size(768, 1024),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
    });
  });
}
