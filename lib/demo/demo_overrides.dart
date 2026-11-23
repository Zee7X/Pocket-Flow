// lib/demo/demo_overrides.dart
//
// Provider overrides berisi data contoh untuk mode preview (lib/demo/demo_main.dart).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/domain/auth_state.dart' as domain;
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/categories_rules/domain/allocation_rule.dart';
import '../features/categories_rules/domain/category.dart';
import '../features/categories_rules/presentation/providers/categories_rules_provider.dart';
import '../features/debts_savings/domain/debt.dart';
import '../features/debts_savings/domain/savings_goal.dart';
import '../features/debts_savings/presentation/providers/debts_savings_provider.dart';
import '../features/reports/domain/monthly_report.dart';
import '../features/reports/presentation/providers/reports_provider.dart';
import '../features/salary_allocation/domain/monthly_budget.dart';
import '../features/salary_allocation/domain/salary_entry.dart';
import '../features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../features/transactions/domain/transaction.dart';
import '../features/transactions/presentation/providers/transactions_provider.dart';
import '../features/alerts/budget_alerts.dart';
import '../features/capture/domain/capture_models.dart';
import '../features/capture/domain/pending_capture.dart';
import '../features/capture/presentation/providers/capture_provider.dart';
import '../features/insights/presentation/providers/history_provider.dart';
import '../features/recurring/domain/recurring_bill.dart';
import '../features/recurring/presentation/providers/recurring_provider.dart';
import '../features/smart/presentation/providers/smart_providers.dart';
import '../features/splits/domain/split_bill.dart';
import '../features/splits/presentation/providers/splits_provider.dart';
import '../features/wallets/domain/wallet.dart';
import '../features/wallets/presentation/providers/wallets_provider.dart';

const demoUserId = 'demo-user';

List<Override> buildDemoOverrides() {
  return [
    supabaseClientProvider.overrideWithValue(
      SupabaseClient(
        'https://demo.invalid',
        'demo-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ),
    authProvider.overrideWith(_DemoAuthNotifier.new),
    monthlyBudgetsProvider.overrideWith((ref) async {
      final p = ref.watch(selectedPeriodProvider);
      return DemoData.budgets(p.month, p.year);
    }),
    salaryHistoryProvider.overrideWith((ref) async => DemoData.salaryHistory()),
    transactionsProvider.overrideWith(_DemoTransactionsNotifier.new),
    categoriesProvider.overrideWith(_DemoCategoriesNotifier.new),
    allocationRulesProvider.overrideWith(_DemoRulesNotifier.new),
    debtsProvider.overrideWith(_DemoDebtsNotifier.new),
    savingsGoalsProvider.overrideWith(_DemoSavingsNotifier.new),
    monthlyReportProvider.overrideWith((ref) async {
      final p = ref.watch(reportSelectedPeriodProvider);
      return DemoData.report(p.month, p.year);
    }),
    walletsProvider.overrideWith(_DemoWalletsNotifier.new),
    pendingCapturesProvider.overrideWith(_DemoPendingNotifier.new),
    recurringBillsProvider.overrideWith(_DemoBillsNotifier.new),
    splitsProvider.overrideWith(_DemoSplitsNotifier.new),
    merchantRulesProvider.overrideWith(_DemoRulesLearn.new),
    recentHistoryProvider.overrideWith((ref) async {
      final now = DateTime.now();
      return [
        for (var i = 0; i < 4; i++)
          ...DemoData.transactions(
            DateTime(now.year, now.month - i).month,
            DateTime(now.year, now.month - i).year,
          ),
      ];
    }),
  ];
}

class _DemoAuthNotifier extends AuthNotifier {
  @override
  domain.AuthState build() => const domain.AuthAuthenticated(
    userId: demoUserId,
    email: 'raka@pocketflow.app',
    displayName: 'Raka',
  );

  @override
  Future<void> signOut() async {}
}

class _DemoTransactionsNotifier extends TransactionsNotifier {
  static final List<TransactionModel> _added = [];

  @override
  Future<List<TransactionModel>> build() async {
    final p = ref.watch(selectedPeriodProvider);
    return [
      ..._added.where(
        (t) =>
            t.transactionDate.month == p.month &&
            t.transactionDate.year == p.year,
      ),
      ...DemoData.transactions(p.month, p.year),
    ];
  }

  @override
  Future<BudgetAlert?> addTransaction({
    String? categoryId,
    required TransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? description,
    String? paymentMethod,
    String? walletId,
    String? toWalletId,
    String? merchant,
    String source = 'manual',
    String? externalRef,
  }) async {
    final cat = DemoData.categories
        .where((c) => c.id == categoryId)
        .firstOrNull;
    final tx = TransactionModel(
      id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
      userId: demoUserId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      transactionDate: transactionDate,
      description: description,
      createdAt: DateTime.now(),
      categoryName: cat?.name,
      walletId: walletId,
      toWalletId: toWalletId,
      merchant: merchant,
      source: source,
    );
    _added.insert(0, tx);
    state = AsyncValue.data([tx, ...(state.value ?? [])]);
    return null;
  }

  @override
  Future<int> addMany(List<TransactionModel> items) async {
    for (final t in items) {
      await addTransaction(
        categoryId: t.categoryId,
        type: t.type,
        amount: t.amount,
        transactionDate: t.transactionDate,
        description: t.description,
        walletId: t.walletId,
        source: t.source,
      );
    }
    return items.length;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _added.removeWhere((t) => t.id == id);
    state = AsyncValue.data(
      (state.value ?? []).where((t) => t.id != id).toList(),
    );
  }
}

class _DemoWalletsNotifier extends WalletsNotifier {
  @override
  Future<List<Wallet>> build() async => DemoData.wallets;

  @override
  Future<Wallet?> ensureForProvider(String? providerKey) async =>
      DemoData.wallets.where((w) => w.providerKey == providerKey).firstOrNull;
}

class _DemoPendingNotifier extends PendingCapturesNotifier {
  @override
  Future<List<PendingCapture>> build() async => DemoData.pending();

  @override
  Future<int> drainNative() async => 0;

  @override
  Future<int> ingest(List<ParsedCapture> items) async {
    final wallets = DemoData.wallets;
    final suggester = ref.read(categorySuggesterProvider);
    final rows = [
      for (final i in items)
        PendingCapture(
          id: 'p-${i.dedupeHash}',
          source: i.source,
          sourceApp: i.sourceApp,
          providerKey: i.providerKey,
          type: i.type,
          amount: i.amount,
          merchant: i.merchant,
          occurredAt: i.occurredAt,
          suggestedCategoryId: i.type == TransactionType.transfer
              ? null
              : suggester
                    .suggest(
                      merchant: i.merchant,
                      isIncome: i.type == TransactionType.income,
                    )
                    ?.categoryId,
          suggestedWalletId: wallets
              .where((w) => w.providerKey == i.providerKey)
              .firstOrNull
              ?.id,
          toWalletId: wallets
              .where((w) => w.providerKey == i.counterpartyProviderKey)
              .firstOrNull
              ?.id,
          confidence: i.confidence,
          dedupeHash: i.dedupeHash,
        ),
    ];
    state = AsyncValue.data([...rows, ...(state.value ?? [])]);
    return rows.length;
  }

  @override
  Future<bool> confirm(
    PendingCapture item, {
    required TransactionType type,
    required int amount,
    required DateTime date,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    String? merchant,
    String? note,
  }) async {
    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          categoryId: categoryId,
          type: type,
          amount: amount,
          transactionDate: date,
          description: note ?? merchant,
          merchant: merchant,
          walletId: walletId,
          toWalletId: toWalletId,
          source: item.source,
        );
    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != item.id).toList(),
    );
    return false;
  }

  @override
  Future<void> dismiss(PendingCapture item) async {
    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != item.id).toList(),
    );
  }
}

class _DemoBillsNotifier extends RecurringBillsNotifier {
  @override
  Future<List<RecurringBill>> build() async => DemoData.bills();

  @override
  Future<void> markPaid(RecurringBill bill, {DateTime? paidAt}) async {
    state = AsyncValue.data([
      for (final b in state.value ?? <RecurringBill>[])
        b.id == bill.id
            ? RecurringBill(
                id: b.id,
                userId: b.userId,
                name: b.name,
                amount: b.amount,
                categoryId: b.categoryId,
                walletId: b.walletId,
                cadence: b.cadence,
                nextDueDate: b.cadence.next(b.nextDueDate),
              )
            : b,
    ]);
  }
}

class _DemoSplitsNotifier extends SplitsNotifier {
  @override
  Future<List<SplitBill>> build() async => DemoData.splits();
}

class _DemoRulesLearn extends MerchantRulesNotifier {
  @override
  Future<Map<String, String>> build() async => const {};

  @override
  Future<void> learn(
    String? merchant,
    String? categoryId, {
    String? walletId,
  }) async {}
}

class _DemoCategoriesNotifier extends CategoriesNotifier {
  @override
  Future<List<Category>> build() async => DemoData.categories;
}

class _DemoRulesNotifier extends AllocationRulesNotifier {
  @override
  Future<List<AllocationRule>> build() async => DemoData.rules;
}

class _DemoDebtsNotifier extends DebtsNotifier {
  @override
  Future<List<Debt>> build() async => DemoData.debts;
}

class _DemoSavingsNotifier extends SavingsGoalsNotifier {
  @override
  Future<List<SavingsGoal>> build() async => DemoData.goals;
}

/// Data contoh yang realistis untuk satu pengguna bergaji Rp8,5 juta.
class DemoData {
  static final _created = DateTime(2026, 1, 1);

  static final categories = <Category>[
    Category(
      id: 'c-makan',
      userId: demoUserId,
      name: 'Makan & Minum',
      type: CategoryType.expense,
      createdAt: _created,
    ),
    Category(
      id: 'c-transport',
      userId: demoUserId,
      name: 'Transportasi',
      type: CategoryType.expense,
      createdAt: _created,
    ),
    Category(
      id: 'c-belanja',
      userId: demoUserId,
      name: 'Belanja',
      type: CategoryType.expense,
      createdAt: _created,
    ),
    Category(
      id: 'c-hiburan',
      userId: demoUserId,
      name: 'Hiburan & Langganan',
      type: CategoryType.expense,
      createdAt: _created,
    ),
    Category(
      id: 'c-kos',
      userId: demoUserId,
      name: 'Sewa Kos',
      type: CategoryType.expense,
      isFixed: true,
      createdAt: _created,
    ),
    Category(
      id: 'c-tagihan',
      userId: demoUserId,
      name: 'Tagihan & Internet',
      type: CategoryType.expense,
      isFixed: true,
      createdAt: _created,
    ),
    Category(
      id: 'c-tabungan',
      userId: demoUserId,
      name: 'Tabungan',
      type: CategoryType.savings,
      createdAt: _created,
    ),
    Category(
      id: 'c-cicilan',
      userId: demoUserId,
      name: 'Cicilan Paylater',
      type: CategoryType.debt,
      createdAt: _created,
    ),
    Category(
      id: 'c-gaji',
      userId: demoUserId,
      name: 'Gaji Utama',
      type: CategoryType.income,
      createdAt: _created,
    ),
    Category(
      id: 'c-freelance',
      userId: demoUserId,
      name: 'Freelance',
      type: CategoryType.income,
      createdAt: _created,
    ),
  ];

  static String _catName(String id) =>
      categories.firstWhere((c) => c.id == id).name;

  static final rules = <AllocationRule>[
    const AllocationRule(
      id: 'r1',
      userId: demoUserId,
      categoryId: 'c-kos',
      name: 'Sewa Kos',
      allocationType: AllocationType.fixed,
      fixedAmount: 1800000,
      priority: 1,
      isRequired: true,
    ),
    const AllocationRule(
      id: 'r2',
      userId: demoUserId,
      categoryId: 'c-tagihan',
      name: 'Tagihan & Internet',
      allocationType: AllocationType.fixed,
      fixedAmount: 450000,
      priority: 2,
      isRequired: true,
    ),
    const AllocationRule(
      id: 'r3',
      userId: demoUserId,
      categoryId: 'c-cicilan',
      name: 'Cicilan Paylater',
      allocationType: AllocationType.fixed,
      fixedAmount: 600000,
      priority: 3,
      isRequired: true,
    ),
    const AllocationRule(
      id: 'r4',
      userId: demoUserId,
      categoryId: 'c-tabungan',
      name: 'Tabungan',
      allocationType: AllocationType.percentage,
      percentage: 20,
      priority: 4,
    ),
    const AllocationRule(
      id: 'r5',
      userId: demoUserId,
      categoryId: 'c-makan',
      name: 'Makan & Minum',
      allocationType: AllocationType.fixed,
      fixedAmount: 2000000,
      priority: 5,
    ),
    const AllocationRule(
      id: 'r6',
      userId: demoUserId,
      categoryId: 'c-transport',
      name: 'Transportasi',
      allocationType: AllocationType.fixed,
      fixedAmount: 600000,
      priority: 6,
    ),
  ];

  static List<MonthlyBudget> budgets(int month, int year) {
    final spent = <String, int>{};
    for (final t in transactions(month, year)) {
      if (t.type == TransactionType.expense && t.categoryId != null) {
        spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amount;
      }
    }
    MonthlyBudget b(
      String id,
      String cat,
      int alloc, {
      String? type,
      bool fixed = false,
    }) => MonthlyBudget(
      id: id,
      userId: demoUserId,
      categoryId: cat,
      periodMonth: month,
      periodYear: year,
      allocatedAmount: alloc,
      spentAmount: spent[cat] ?? 0,
      categoryName: _catName(cat),
      categoryType: type ?? 'expense',
      categoryIsFixed: fixed,
    );
    return [
      b('b1', 'c-kos', 1800000, fixed: true),
      b('b2', 'c-tagihan', 450000, fixed: true),
      b('b3', 'c-cicilan', 600000, type: 'debt'),
      b('b4', 'c-tabungan', 1300000, type: 'saving'),
      b('b5', 'c-makan', 2000000),
      b('b6', 'c-transport', 600000),
      b('b7', 'c-belanja', 900000),
      b('b8', 'c-hiburan', 350000),
    ];
  }

  static List<SalaryEntry> salaryHistory() {
    final now = DateTime.now();
    return List.generate(3, (i) {
      final d = DateTime(now.year, now.month - i, 1);
      return SalaryEntry(
        id: 's$i',
        userId: demoUserId,
        amount: 8500000,
        salaryDate: DateTime(d.year, d.month, 1),
        periodMonth: d.month,
        periodYear: d.year,
        createdAt: d,
      );
    });
  }

  /// Transaksi contoh untuk sebuah bulan. Bulan berjalan hanya sampai hari ini.
  static List<TransactionModel> transactions(int month, int year) {
    final now = DateTime.now();
    final isCurrent = month == now.month && year == now.year;
    final lastDay = isCurrent ? now.day : DateTime(year, month + 1, 0).day;
    // Bulan lalu sedikit lebih boros supaya insight punya bahan.
    final factor = isCurrent ? 1.0 : 1.18;

    final out = <TransactionModel>[];
    var seq = 0;
    void add(
      int day,
      TransactionType type,
      int amount,
      String? cat,
      String note, {
      String? method,
    }) {
      if (day > lastDay) return;
      seq++;
      final date = DateTime(year, month, day);
      out.add(
        TransactionModel(
          id: 'tx-$year$month-$seq',
          userId: demoUserId,
          categoryId: cat,
          type: type,
          amount:
              type == TransactionType.expense &&
                  cat != 'c-kos' &&
                  cat != 'c-tagihan'
              ? (amount * factor).round()
              : amount,
          transactionDate: date,
          description: note,
          paymentMethod: method,
          createdAt: date.add(Duration(hours: 8 + (seq % 12))),
          categoryName: cat == null ? null : _catName(cat),
          merchant: note,
          walletId: switch (method) {
            'E-Wallet' => seq.isEven ? 'w-gopay' : 'w-ovo',
            'QRIS' => 'w-gopay',
            'Transfer Bank' || 'Debit' => 'w-bca',
            _ => 'w-cash',
          },
          source: method == 'E-Wallet' && seq % 3 == 0
              ? 'notification'
              : 'manual',
        ),
      );
    }

    add(
      1,
      TransactionType.income,
      8500000,
      'c-gaji',
      'Gaji November',
      method: 'Transfer Bank',
    );
    add(
      1,
      TransactionType.expense,
      1800000,
      'c-kos',
      'Sewa kos bulanan',
      method: 'Transfer Bank',
    );
    add(
      2,
      TransactionType.expense,
      1300000,
      'c-tabungan',
      'Setor: Dana Darurat',
      method: 'Transfer Bank',
    );
    add(
      3,
      TransactionType.expense,
      325000,
      'c-tagihan',
      'IndiHome',
      method: 'Transfer Bank',
    );
    add(
      5,
      TransactionType.expense,
      600000,
      'c-cicilan',
      'Bayar SPayLater',
      method: 'E-Wallet',
    );
    add(
      6,
      TransactionType.expense,
      54000,
      'c-hiburan',
      'Spotify Premium',
      method: 'E-Wallet',
    );
    add(
      8,
      TransactionType.expense,
      186000,
      'c-hiburan',
      'Netflix',
      method: 'Debit',
    );
    add(
      12,
      TransactionType.income,
      1250000,
      'c-freelance',
      'Desain logo klien',
      method: 'Transfer Bank',
    );

    const meals = [
      'GoFood - Ayam Geprek',
      'Kopi Kenangan',
      'ShopeeFood - Bakso',
      'Warteg Bahari',
      'GrabFood - Nasi Padang',
    ];
    const rides = ['GoRide ke kantor', 'KRL Commuter', 'GrabBike pulang'];
    for (var d = 1; d <= 30; d++) {
      add(
        d,
        TransactionType.expense,
        28000 + (d * 7919) % 42000,
        'c-makan',
        meals[d % meals.length],
        method: 'E-Wallet',
      );
      if (d % 2 == 0) {
        add(
          d,
          TransactionType.expense,
          14000 + (d * 3571) % 16000,
          'c-transport',
          rides[d % rides.length],
          method: 'E-Wallet',
        );
      }
      if (d % 6 == 0) {
        add(
          d,
          TransactionType.expense,
          95000 + (d * 15013) % 160000,
          'c-belanja',
          d % 12 == 0 ? 'Tokopedia - Kebutuhan kos' : 'Indomaret',
          method: 'QRIS',
        );
      }
    }
    out.sort((a, b) {
      final c = b.transactionDate.compareTo(a.transactionDate);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return out;
  }

  static final debts = <Debt>[
    Debt(
      id: 'd1',
      userId: demoUserId,
      name: 'SPayLater',
      debtType: DebtType.paylater,
      totalAmount: 3600000,
      remainingAmount: 1800000,
      minimumPayment: 600000,
      dueDay: 5,
      createdAt: _created,
    ),
    Debt(
      id: 'd2',
      userId: demoUserId,
      name: 'Pinjaman Kakak',
      debtType: DebtType.personalLoan,
      totalAmount: 2000000,
      remainingAmount: 500000,
      createdAt: _created,
    ),
  ];

  static final goals = <SavingsGoal>[
    SavingsGoal(
      id: 'g1',
      userId: demoUserId,
      name: 'Dana Darurat',
      goalType: GoalType.emergencyFund,
      targetAmount: 25000000,
      currentAmount: 9100000,
      createdAt: _created,
    ),
    SavingsGoal(
      id: 'g2',
      userId: demoUserId,
      name: 'Laptop Baru',
      goalType: GoalType.purchase,
      targetAmount: 15000000,
      currentAmount: 4200000,
      createdAt: _created,
    ),
  ];

  static final wallets = <Wallet>[
    const Wallet(
      id: 'w-bca',
      userId: demoUserId,
      name: 'BCA',
      kind: WalletKind.bank,
      providerKey: 'bca',
      color: '#0060AF',
      balance: 4870000,
    ),
    const Wallet(
      id: 'w-gopay',
      userId: demoUserId,
      name: 'GoPay',
      kind: WalletKind.ewallet,
      providerKey: 'gopay',
      color: '#00AA13',
      balance: 236500,
    ),
    const Wallet(
      id: 'w-ovo',
      userId: demoUserId,
      name: 'OVO',
      kind: WalletKind.ewallet,
      providerKey: 'ovo',
      color: '#4C3494',
      balance: 87000,
    ),
    const Wallet(
      id: 'w-cash',
      userId: demoUserId,
      name: 'Tunai',
      kind: WalletKind.cash,
      providerKey: 'cash',
      color: '#475569',
      balance: 150000,
    ),
    const Wallet(
      id: 'w-spl',
      userId: demoUserId,
      name: 'SPayLater',
      kind: WalletKind.paylater,
      providerKey: 'spaylater',
      color: '#EE4D2D',
      balance: -1800000,
    ),
  ];

  static List<PendingCapture> pending() {
    final now = DateTime.now();
    return [
      PendingCapture(
        id: 'p1',
        source: 'notification',
        sourceApp: 'GoPay',
        providerKey: 'gopay',
        type: TransactionType.expense,
        amount: 32000,
        merchant: 'Kopi Kenangan',
        occurredAt: now.subtract(const Duration(minutes: 18)),
        suggestedCategoryId: 'c-makan',
        suggestedWalletId: 'w-gopay',
        confidence: 0.9,
        dedupeHash: 'd1',
      ),
      PendingCapture(
        id: 'p2',
        source: 'notification',
        sourceApp: 'BCA → GoPay',
        providerKey: 'bca',
        type: TransactionType.transfer,
        amount: 200000,
        merchant: 'Top up GoPay',
        occurredAt: now.subtract(const Duration(hours: 2)),
        suggestedWalletId: 'w-bca',
        toWalletId: 'w-gopay',
        confidence: 0.85,
        dedupeHash: 'd2',
      ),
      PendingCapture(
        id: 'p3',
        source: 'notification',
        sourceApp: 'OVO',
        providerKey: 'ovo',
        type: TransactionType.income,
        amount: 150000,
        merchant: 'Budi Santoso',
        occurredAt: now.subtract(const Duration(hours: 5)),
        suggestedWalletId: 'w-ovo',
        confidence: 0.8,
        dedupeHash: 'd3',
      ),
      PendingCapture(
        id: 'p4',
        source: 'notification',
        sourceApp: 'DANA',
        providerKey: 'dana',
        type: TransactionType.expense,
        amount: 18500,
        merchant: 'Warung Bu Tini',
        occurredAt: now.subtract(const Duration(days: 1, hours: 3)),
        confidence: 0.75,
        dedupeHash: 'd4',
      ),
    ];
  }

  static List<RecurringBill> bills() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      RecurringBill(
        id: 'rb1',
        userId: demoUserId,
        name: 'Netflix',
        amount: 186000,
        categoryId: 'c-hiburan',
        walletId: 'w-bca',
        nextDueDate: today.add(const Duration(days: 2)),
      ),
      RecurringBill(
        id: 'rb2',
        userId: demoUserId,
        name: 'Spotify Premium',
        amount: 54000,
        categoryId: 'c-hiburan',
        walletId: 'w-gopay',
        nextDueDate: today.add(const Duration(days: 5)),
      ),
      RecurringBill(
        id: 'rb3',
        userId: demoUserId,
        name: 'IndiHome',
        amount: 325000,
        categoryId: 'c-tagihan',
        walletId: 'w-bca',
        nextDueDate: today.add(const Duration(days: 11)),
      ),
      RecurringBill(
        id: 'rb4',
        userId: demoUserId,
        name: 'SPayLater',
        amount: 600000,
        categoryId: 'c-cicilan',
        walletId: 'w-bca',
        debtId: 'd1',
        nextDueDate: today.add(const Duration(days: 13)),
      ),
    ];
  }

  static List<SplitBill> splits() {
    final now = DateTime.now();
    return [
      SplitBill(
        id: 's1',
        title: 'Makan malam Sate Senayan',
        totalAmount: 480000,
        myShare: 120000,
        splitDate: now.subtract(const Duration(days: 3)),
        walletId: 'w-bca',
        participants: const [
          SplitParticipant(
            id: 'sp1',
            name: 'Dimas',
            shareAmount: 120000,
            isSettled: true,
          ),
          SplitParticipant(id: 'sp2', name: 'Nadia', shareAmount: 120000),
          SplitParticipant(id: 'sp3', name: 'Yoga', shareAmount: 120000),
        ],
      ),
      SplitBill(
        id: 's2',
        title: 'Tiket Prambanan Jazz',
        totalAmount: 1500000,
        myShare: 750000,
        splitDate: now.subtract(const Duration(days: 12)),
        participants: const [
          SplitParticipant(id: 'sp4', name: 'Ayu', shareAmount: 750000),
        ],
      ),
    ];
  }

  static MonthlyReport report(int month, int year) {
    final txs = transactions(month, year);
    var income = 0, expense = 0, savings = 0, debt = 0;
    final byCat = <String, int>{};
    for (final t in txs) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else if (t.type == TransactionType.expense) {
        if (t.categoryId == 'c-tabungan') {
          savings += t.amount;
        } else if (t.categoryId == 'c-cicilan') {
          debt += t.amount;
        } else {
          expense += t.amount;
        }
        byCat[t.categoryId ?? '-'] =
            (byCat[t.categoryId ?? '-'] ?? 0) + t.amount;
      }
    }
    final budgetList = budgets(month, year);
    final totalSpent = byCat.values.fold<int>(0, (a, b) => a + b);
    return MonthlyReport(
      month: month,
      year: year,
      totalIncome: income,
      totalExpense: expense,
      totalSavings: savings,
      totalDebtPayment: debt,
      netCashFlow: income - expense - savings - debt,
      savingsRate: income > 0 ? savings / income * 100 : 0,
      categoryBreakdown: budgetList
          .map(
            (b) => CategorySpendingSummary(
              categoryName: b.categoryName ?? '-',
              allocatedAmount: b.allocatedAmount,
              spentAmount: b.spentAmount,
              percentageOfTotalSpent: totalSpent > 0
                  ? b.spentAmount / totalSpent
                  : 0,
            ),
          )
          .toList(),
      rawBudgets: budgetList,
    );
  }
}
