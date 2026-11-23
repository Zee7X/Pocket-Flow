// lib/features/transactions/presentation/providers/transactions_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/offline/offline_queue.dart';
import '../../../../core/storage/local_store.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/debts_savings/presentation/providers/debts_savings_provider.dart';
import '../../../../features/reports/presentation/providers/reports_provider.dart';
import '../../../../features/salary_allocation/presentation/providers/salary_allocation_provider.dart';
import '../../../alerts/budget_alerts.dart';
import '../../../smart/presentation/providers/smart_providers.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../../salary_allocation/domain/salary_duplicate.dart';
import '../../data/transaction_repository.dart';
import '../../domain/transaction.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(supabaseClientProvider));
});

final offlineQueueProvider = Provider<OfflineQueue?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return OfflineQueue(ref.watch(maybeLocalStoreProvider), uid);
});

/// Jumlah transaksi yang masih menunggu dikirim ke server.
final pendingSyncCountProvider = Provider<int>((ref) {
  ref.watch(transactionsProvider);
  return ref.watch(offlineQueueProvider)?.pending().length ?? 0;
});

// Transactions list for selected month/year
final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];
    final period = ref.watch(selectedPeriodProvider);
    final queue = ref.watch(offlineQueueProvider);

    // Kirim ulang antrean offline setiap kali koneksi kembali.
    ref.listen<AsyncValue<bool>>(connectivityProvider, (prev, next) {
      if (next.value == true && prev?.value == false) {
        syncOffline();
      }
    });

    List<TransactionModel> list;
    try {
      list = await ref
          .watch(transactionRepositoryProvider)
          .getTransactions(month: period.month, year: period.year);
      // Cache untuk dibuka saat offline.
      queue?.cacheMonth(period.month, period.year, [
        for (final t in list) _toCacheJson(t),
      ]);
    } catch (e) {
      final cached = queue?.cachedMonth(period.month, period.year);
      if (!isNetworkError(e) || cached == null) rethrow;
      list = cached.map(TransactionModel.fromJson).toList();
    }

    // Gabungkan transaksi yang dibuat offline dan belum terkirim.
    final pending = queue?.pending() ?? const [];
    final local = <TransactionModel>[];
    for (final p in pending) {
      final t = _fromQueue(p, userId);
      if (t.transactionDate.month == period.month &&
          t.transactionDate.year == period.year) {
        local.add(t);
      }
    }
    if (pending.isNotEmpty) {
      Future.microtask(syncOffline);
    }
    return [...local, ...list];
  }

  Map<String, dynamic> _toCacheJson(TransactionModel t) => {
    'id': t.id,
    'user_id': t.userId,
    'category_id': t.categoryId,
    'type': t.type.toDbString(),
    'amount': t.amount,
    'transaction_date': t.transactionDate.toIso8601String().split('T').first,
    'note': t.description,
    'payment_method': t.paymentMethod,
    'created_at': t.createdAt.toIso8601String(),
    'wallet_id': t.walletId,
    'to_wallet_id': t.toWalletId,
    'merchant': t.merchant,
    'source': t.source,
    'external_ref': t.externalRef,
    'pf_categories': t.categoryName == null
        ? null
        : {
            'name': t.categoryName,
            'type': t.categoryType,
            'icon': t.categoryIcon,
            'color': t.categoryColor,
          },
  };

  TransactionModel _fromQueue(Map<String, dynamic> p, String userId) {
    return TransactionModel.fromJson({
      ...p,
      'id': p['local_id'],
      'user_id': userId,
      'created_at': p['created_at'] ?? DateTime.now().toIso8601String(),
      '_pending_sync': true,
    });
  }

  bool _syncing = false;

  /// Kirim antrean offline ke server. Aman dipanggil berulang.
  Future<int> syncOffline() async {
    final queue = ref.read(offlineQueueProvider);
    if (queue == null || _syncing) return 0;
    _syncing = true;
    var sent = 0;
    try {
      for (final p in queue.pending()) {
        try {
          await ref
              .read(transactionRepositoryProvider)
              .createTransaction(
                categoryId: p['category_id'] as String?,
                type: TransactionType.fromString(p['type'] as String),
                amount: (p['amount'] as num).toInt(),
                transactionDate: DateTime.parse(
                  p['transaction_date'] as String,
                ),
                description: p['note'] as String?,
                paymentMethod: p['payment_method'] as String?,
                walletId: p['wallet_id'] as String?,
                toWalletId: p['to_wallet_id'] as String?,
                merchant: p['merchant'] as String?,
                source: p['source'] as String? ?? 'manual',
                externalRef:
                    p['external_ref'] as String? ?? p['local_id'] as String?,
              );
          await queue.remove(p['local_id'] as String);
          sent++;
        } catch (e) {
          if (isNetworkError(e)) break; // masih offline, coba lagi nanti
          // Error lain (mis. duplikat external_ref = sudah pernah terkirim).
          await queue.remove(p['local_id'] as String);
        }
      }
    } finally {
      _syncing = false;
    }
    if (sent > 0) {
      ref.invalidateSelf();
      _invalidateRelated();
    }
    return sent;
  }

  void _invalidateRelated() {
    ref.invalidate(monthlyBudgetsProvider);
    ref.invalidate(monthlyReportProvider);
    ref.invalidate(debtsProvider);
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(walletsProvider);
  }

  /// Simpan transaksi baru. Bila offline, transaksi masuk antrean dan tetap
  /// tampil di daftar. Mengembalikan peringatan budget bila ada.
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
    TransactionModel newTx;
    try {
      newTx = await ref
          .read(transactionRepositoryProvider)
          .createTransaction(
            categoryId: categoryId,
            type: type,
            amount: amount,
            transactionDate: transactionDate,
            description: description,
            paymentMethod: paymentMethod,
            walletId: walletId,
            toWalletId: toWalletId,
            merchant: merchant,
            source: source,
            externalRef: externalRef,
          );
    } catch (e) {
      final queue = ref.read(offlineQueueProvider);
      if (!isNetworkError(e) || queue == null) rethrow;
      final localId = 'local-${const Uuid().v4()}';
      final row = <String, dynamic>{
        'local_id': localId,
        'category_id': categoryId,
        'type': type.toDbString(),
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String().split('T').first,
        'note': description,
        'payment_method': paymentMethod,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'merchant': merchant,
        'source': source,
        'external_ref': externalRef ?? localId,
        'created_at': DateTime.now().toIso8601String(),
      };
      await queue.enqueue(row);
      state = AsyncValue.data([
        _fromQueue(row, ref.read(currentUserIdProvider) ?? ''),
        ...(state.value ?? []),
      ]);
      return null;
    }

    // In-place update to prevent full page reload / spinner
    state = AsyncValue.data([newTx, ...(state.value ?? [])]);

    // Belajar kategori dari merchant / catatan.
    ref
        .read(merchantRulesProvider.notifier)
        .learn(merchant ?? description, categoryId, walletId: walletId);

    _invalidateRelated();
    return _checkAlert(type, categoryId, amount, transactionDate);
  }

  Future<BudgetAlert?> _checkAlert(
    TransactionType type,
    String? categoryId,
    int amount,
    DateTime date,
  ) async {
    if (type != TransactionType.expense || categoryId == null) return null;
    final period = ref.read(selectedPeriodProvider);
    if (period.month != date.month || period.year != date.year) return null;
    try {
      final budgets = await ref.read(monthlyBudgetsProvider.future);
      final b = budgets.where((x) => x.categoryId == categoryId).firstOrNull;
      final alert = await checkBudgetAlert(ref, budgetAfter: b, amount: amount);
      if (alert != null) {
        ref.read(lastBudgetAlertProvider.notifier).state = alert;
      }
      return alert;
    } catch (_) {
      return null;
    }
  }

  /// Bila pemasukan ini adalah gaji yang sudah tercatat lewat Alokasi Gaji,
  /// kembalikan transaksi gaji tersebut. Null = bukan duplikat.
  Future<TransactionModel?> findSalaryDuplicate({
    required int amount,
    required DateTime date,
    String? text,
  }) async {
    try {
      final entries = await ref.read(salaryHistoryProvider.future);
      final e = matchSalaryEntry(entries, amount: amount, date: date, text: text);
      if (e == null) return null;
      return await ref
          .read(transactionRepositoryProvider)
          .findIncomeByNote(salaryTransactionNote(e));
    } catch (_) {
      return null;
    }
  }

  /// Gabungkan pemasukan yang terdeteksi ke transaksi gaji yang sudah ada:
  /// tidak membuat transaksi baru, hanya melengkapi dompet tujuannya.
  Future<void> mergeIntoSalary(TransactionModel salaryTx, {String? walletId}) async {
    if (walletId != null && salaryTx.walletId == null) {
      await ref.read(transactionRepositoryProvider).setWallet(salaryTx.id, walletId);
      _invalidateRelated();
      ref.invalidateSelf();
    }
  }

  /// Simpan banyak transaksi (import). Mengembalikan jumlah yang tersimpan.
  Future<int> addMany(List<TransactionModel> items) async {
    final n = await ref.read(transactionRepositoryProvider).createMany(items);
    // Rekalibrasi budget untuk bulan-bulan yang terdampak.
    final months = {
      for (final t in items) (t.transactionDate.month, t.transactionDate.year),
    };
    final savingsRepo = ref.read(savingsRepositoryProvider);
    for (final (m, y) in months) {
      await savingsRepo.recalibrateMonthlyBudgets(month: m, year: y);
    }
    ref.invalidateSelf();
    _invalidateRelated();
    return n;
  }

  Future<void> editTransaction({
    required String id,
    String? categoryId,
    required TransactionType type,
    required int amount,
    required DateTime transactionDate,
    String? description,
    String? paymentMethod,
    String? walletId,
    String? toWalletId,
    String? merchant,
  }) async {
    final updatedTx = await ref
        .read(transactionRepositoryProvider)
        .updateTransaction(
          id: id,
          categoryId: categoryId,
          type: type,
          amount: amount,
          transactionDate: transactionDate,
          description: description,
          paymentMethod: paymentMethod,
          walletId: walletId,
          toWalletId: toWalletId,
          merchant: merchant,
        );

    state = AsyncValue.data(
      (state.value ?? []).map((t) => t.id == id ? updatedTx : t).toList(),
    );

    ref
        .read(merchantRulesProvider.notifier)
        .learn(merchant ?? description, categoryId, walletId: walletId);
    _invalidateRelated();
  }

  Future<void> deleteTransaction(String id) async {
    if (id.startsWith('local-')) {
      await ref.read(offlineQueueProvider)?.remove(id);
    } else {
      await ref.read(transactionRepositoryProvider).deleteTransaction(id);
    }

    state = AsyncValue.data(
      (state.value ?? []).where((t) => t.id != id).toList(),
    );
    _invalidateRelated();
  }
}
