// Audit overflow: semua halaman utama di HP kecil (320 px), teks diperbesar
// 130% (pengaturan aksesibilitas), nama dan nominal yang sangat panjang.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_flow/app/theme.dart';
import 'package:pocket_flow/demo/demo_overrides.dart';
import 'package:pocket_flow/features/auth/domain/auth_state.dart' as domain;
import 'package:pocket_flow/features/auth/presentation/providers/auth_provider.dart';
import 'package:pocket_flow/features/capture/presentation/inbox_page.dart';
import 'package:pocket_flow/features/categories_rules/presentation/categories_rules_page.dart';
import 'package:pocket_flow/features/dashboard/presentation/dashboard_page.dart';
import 'package:pocket_flow/features/debts_savings/presentation/debts_savings_page.dart';
import 'package:pocket_flow/features/import/presentation/import_page.dart';
import 'package:pocket_flow/features/more/more_page.dart';
import 'package:pocket_flow/features/recurring/presentation/recurring_page.dart';
import 'package:pocket_flow/features/reports/presentation/monthly_reports_page.dart';
import 'package:pocket_flow/features/salary_allocation/presentation/salary_allocation_page.dart';
import 'package:pocket_flow/features/splits/presentation/splits_page.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';
import 'package:pocket_flow/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:pocket_flow/features/transactions/presentation/transactions_page.dart';
import 'package:pocket_flow/features/transactions/presentation/widgets/add_transaction_dialog.dart';
import 'package:pocket_flow/features/wallets/presentation/wallets_page.dart';
import 'package:pocket_flow/features/capture/presentation/capture_settings_page.dart';
import 'package:pocket_flow/features/capture/presentation/widgets/paste_capture_sheet.dart';
import 'package:pocket_flow/features/smart/domain/quick_text_parser.dart';
import 'package:pocket_flow/features/smart/presentation/smart_input_sheet.dart';
import 'package:pocket_flow/features/smart/presentation/widgets/draft_editor_sheet.dart';

class _LongNameAuth extends AuthNotifier {
  @override
  domain.AuthState build() => const domain.AuthAuthenticated(
        userId: demoUserId,
        email: 'a@b.c',
        displayName: 'Bartholomew Alexander Wicaksono Pranoto Hadiningrat',
      );
}

class _HugeTx extends TransactionsNotifier {
  @override
  Future<List<TransactionModel>> build() async {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'x1',
        userId: demoUserId,
        type: TransactionType.income,
        amount: 1250000000,
        transactionDate: now,
        description: 'Pembayaran proyek konsultasi sistem informasi keuangan tahap ketiga untuk klien',
        categoryName: 'Pendapatan Lain-lain dari Usaha Sampingan',
        walletId: 'w-bca',
        source: 'notification',
        createdAt: now,
      ),
      ...DemoData.transactions(now.month, now.year),
    ];
  }
}

Widget _app(Widget child) => ProviderScope(
      overrides: [
        ...buildDemoOverrides(),
        authProvider.overrideWith(_LongNameAuth.new),
        transactionsProvider.overrideWith(_HugeTx.new),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: c!,
        ),
        home: child,
      ),
    );

void main() {
  final pages = <String, Widget>{
    'Dashboard': const DashboardPage(),
    'Transaksi': const TransactionsPage(),
    'Perlu Ditinjau': const InboxPage(),
    'Dompet': const WalletsPage(),
    'Tagihan': const RecurringPage(),
    'Patungan': const SplitsPage(),
    'Lainnya': const MorePage(),
    'Laporan': const MonthlyReportsPage(),
    'Alokasi': const SalaryAllocationPage(),
    'Target & Utang': const DebtsSavingsPage(),
    'Kategori': const CategoriesRulesPage(),
    'Import': const ImportPage(),
    'Deteksi': const CaptureSettingsPage(),
    'Form transaksi': const Scaffold(body: AddTransactionDialog()),
    'Catat pintar': const Scaffold(body: SmartInputSheet()),
    'Catat suara': const Scaffold(body: SmartInputSheet(autoSave: true)),
    'Tempel teks': const Scaffold(body: PasteCaptureSheet()),
    'Tinjau transaksi': Scaffold(
      body: DraftEditorSheet(
        title: 'Tinjau transaksi',
        subtitle: 'Terbaca dari GoPay',
        draft: DraftTransaction(
          type: TransactionType.expense,
          amount: 1250000000,
          merchant: 'Restoran Seafood Bandar Djakarta Cabang Ancol Jakarta Utara',
          date: DateTime(2026, 11, 23),
          categoryId: 'c-makan',
          walletId: 'w-gopay',
        ),
      ),
    ),
  };

  for (final size in const [Size(320, 640), Size(390, 844)]) {
    for (final e in pages.entries) {
      testWidgets('${e.key} tanpa overflow (${size.width.toInt()}px, teks 130%)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(_app(e.value));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
