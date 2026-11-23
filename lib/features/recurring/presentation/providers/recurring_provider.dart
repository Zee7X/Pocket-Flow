// lib/features/recurring/presentation/providers/recurring_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../core/utils/hash.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../debts_savings/presentation/providers/debts_savings_provider.dart';
import '../../../insights/presentation/providers/history_provider.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../data/recurring_repository.dart';
import '../../domain/recurring_bill.dart';
import '../../domain/recurring_detector.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository(ref.watch(supabaseClientProvider));
});

final recurringBillsProvider =
    AsyncNotifierProvider<RecurringBillsNotifier, List<RecurringBill>>(
      RecurringBillsNotifier.new,
    );

class RecurringBillsNotifier extends AsyncNotifier<List<RecurringBill>> {
  @override
  Future<List<RecurringBill>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    List<RecurringBill> bills;
    try {
      bills = await ref.watch(recurringRepositoryProvider).getBills();
    } catch (_) {
      return const [];
    }
    _scheduleReminders(bills);
    return bills;
  }

  static int _notifId(String billId) =>
      5000 + int.parse(stableHash(billId).substring(0, 6), radix: 16) % 90000;

  Future<void> _scheduleReminders(List<RecurringBill> bills) async {
    final svc = NotificationService();
    for (final b in bills) {
      final id = _notifId(b.id);
      try {
        await svc.cancel(id);
        final remindAt = b.nextDueDate.subtract(
          Duration(days: b.remindDaysBefore),
        );
        await svc.scheduleBillReminder(
          id: id,
          title: b.remindDaysBefore == 0
              ? '${b.name} jatuh tempo hari ini'
              : '${b.name} jatuh tempo ${b.remindDaysBefore} hari lagi',
          body:
              'Tagihan Rp${_fmt(b.amount)}. Buka PocketFlow untuk mencatat pembayaran.',
          date: remindAt,
        );
      } catch (_) {}
    }
  }

  static String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );

  Future<void> save({
    String? id,
    required String name,
    required int amount,
    String? categoryId,
    String? walletId,
    String? debtId,
    required BillCadence cadence,
    required DateTime nextDueDate,
    int remindDaysBefore = 2,
    String? merchantKey,
  }) async {
    await ref
        .read(recurringRepositoryProvider)
        .upsert(
          id: id,
          name: name,
          amount: amount,
          categoryId: categoryId,
          walletId: walletId,
          debtId: debtId,
          cadence: cadence,
          nextDueDate: nextDueDate,
          remindDaysBefore: remindDaysBefore,
          merchantKey: merchantKey,
        );
    ref.invalidateSelf();
  }

  /// Catat pembayaran tagihan: buat transaksi, kurangi utang bila tertaut,
  /// lalu majukan jatuh tempo ke periode berikutnya.
  Future<void> markPaid(RecurringBill bill, {DateTime? paidAt}) async {
    final date = paidAt ?? DateTime.now();
    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          categoryId: bill.categoryId,
          type: TransactionType.expense,
          amount: bill.amount,
          transactionDate: date,
          description: bill.debtId != null
              ? 'Cicilan: ${bill.name}'
              : bill.name,
          merchant: bill.name,
          walletId: bill.walletId,
          source: 'recurring',
        );
    if (bill.debtId != null) {
      try {
        await ref
            .read(debtsProvider.notifier)
            .recordPayment(
              debtId: bill.debtId!,
              amount: bill.amount,
              paymentDate: date,
              note: 'Cicilan: ${bill.name}',
            );
      } catch (_) {}
    }
    await ref
        .read(recurringRepositoryProvider)
        .advance(bill.id, bill.cadence.next(bill.nextDueDate));
    ref.invalidateSelf();
  }

  Future<void> remove(RecurringBill bill) async {
    await ref.read(recurringRepositoryProvider).deactivate(bill.id);
    await NotificationService().cancel(_notifId(bill.id));
    state = AsyncValue.data(
      (state.value ?? []).where((b) => b.id != bill.id).toList(),
    );
  }
}

/// Kunci merchant yang sarannya ditolak pengguna.
final dismissedRecurringProvider =
    NotifierProvider<DismissedRecurringNotifier, Set<String>>(
      DismissedRecurringNotifier.new,
    );

class DismissedRecurringNotifier extends Notifier<Set<String>> {
  static const _key = 'recurring_dismissed';
  @override
  Set<String> build() {
    final raw = ref.watch(maybeLocalStoreProvider)?.getJson(_key);
    return raw is List ? raw.cast<String>().toSet() : <String>{};
  }

  Future<void> dismiss(String key) async {
    state = {...state, key};
    await ref.read(maybeLocalStoreProvider)?.setJson(_key, state.toList());
  }
}

final recurringSuggestionsProvider = Provider<List<RecurringSuggestion>>((ref) {
  final history = ref.watch(recentHistoryProvider).value ?? const [];
  final bills = ref.watch(recurringBillsProvider).value ?? const [];
  final dismissed = ref.watch(dismissedRecurringProvider);
  return const RecurringDetector().detect(
    history,
    ignoreKeys: {
      ...dismissed,
      ...bills.map((b) => b.merchantKey).whereType<String>(),
    },
  );
});

/// Tagihan yang jatuh tempo dalam 7 hari ke depan (untuk dashboard).
final upcomingBillsProvider = Provider<List<RecurringBill>>((ref) {
  final now = DateTime.now();
  return (ref.watch(recurringBillsProvider).value ?? const [])
      .where((b) => b.daysUntilDue(now) <= 7)
      .toList();
});
