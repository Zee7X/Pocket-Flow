// lib/features/transactions/data/transaction_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/transaction.dart';

/// Kolom yang di-select bersama relasi kategori.
const kTransactionSelect = '*, pf_categories(name, icon, color, type)';

class TransactionRepository {
  final SupabaseClient _client;

  TransactionRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  static String _date(DateTime d) => d.toIso8601String().split('T').first;

  /// Fetch transactions for a given month and year
  Future<List<TransactionModel>> getTransactions({
    required int month,
    required int year,
  }) async {
    return getTransactionsBetween(
      start: DateTime(year, month, 1),
      endExclusive: DateTime(year, month + 1, 1),
    );
  }

  /// Transaksi dalam rentang tanggal [start, endExclusive).
  Future<List<TransactionModel>> getTransactionsBetween({
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final res = await _client
        .from('pf_transactions')
        .select(kTransactionSelect)
        .eq('user_id', _userId)
        .gte('transaction_date', _date(start))
        .lt('transaction_date', _date(endExclusive))
        .order('transaction_date', ascending: false)
        .order('created_at', ascending: false);

    return (res as List)
        .map((json) => TransactionModel.fromJson(json))
        .toList();
  }

  Map<String, dynamic> _buildRow({
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
  }) {
    final map = <String, dynamic>{
      'user_id': _userId,
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': _date(transactionDate),
      'source': source,
      // Transfer antar dompet tidak memakai kategori budget.
      'category_id': type == TransactionType.transfer ? null : categoryId,
      'wallet_id': walletId,
      'to_wallet_id': type == TransactionType.transfer ? toWalletId : null,
      'payment_method': paymentMethod,
      'merchant': merchant?.trim().isEmpty == true ? null : merchant?.trim(),
    };
    if (description != null) map['note'] = description.trim();
    if (externalRef != null) map['external_ref'] = externalRef;
    return map;
  }

  /// Create a transaction and sync monthly budget spent_amount
  Future<TransactionModel> createTransaction({
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
    final map = _buildRow(
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

    final res = await _client
        .from('pf_transactions')
        .insert(map)
        .select(kTransactionSelect)
        .single();

    final tx = TransactionModel.fromJson(res);

    // If expense with category, add to spent_amount in pf_monthly_budgets
    if (type == TransactionType.expense && categoryId != null) {
      await _adjustBudgetSpent(
        categoryId: categoryId,
        month: transactionDate.month,
        year: transactionDate.year,
        delta: amount,
      );
    }

    return tx;
  }

  /// Insert banyak transaksi sekaligus (import). Baris dengan external_ref
  /// yang sudah ada dilewati. Mengembalikan jumlah baris yang benar-benar
  /// tersimpan. Budget bulanan TIDAK disesuaikan di sini; pemanggil wajib
  /// menjalankan rekalibrasi untuk bulan-bulan yang terdampak.
  Future<int> createMany(List<TransactionModel> items) async {
    if (items.isEmpty) return 0;

    // Buang duplikat berdasarkan external_ref yang sudah ada di server.
    final refs = items.map((e) => e.externalRef).whereType<String>().toSet();
    final existing = <String>{};
    final refList = refs.toList();
    for (var i = 0; i < refList.length; i += 200) {
      final chunk = refList.sublist(i, (i + 200).clamp(0, refList.length));
      final res = await _client
          .from('pf_transactions')
          .select('external_ref')
          .eq('user_id', _userId)
          .inFilter('external_ref', chunk);
      for (final r in (res as List)) {
        final v = r['external_ref'] as String?;
        if (v != null) existing.add(v);
      }
    }

    final rows = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final t in items) {
      final ref = t.externalRef;
      if (ref != null && (existing.contains(ref) || !seen.add(ref))) continue;
      rows.add(
        _buildRow(
          categoryId: t.categoryId,
          type: t.type,
          amount: t.amount,
          transactionDate: t.transactionDate,
          description: t.description,
          paymentMethod: t.paymentMethod,
          walletId: t.walletId,
          toWalletId: t.toWalletId,
          merchant: t.merchant,
          source: t.source,
          externalRef: ref,
        ),
      );
    }

    var inserted = 0;
    for (var i = 0; i < rows.length; i += 200) {
      final chunk = rows.sublist(i, (i + 200).clamp(0, rows.length));
      await _client.from('pf_transactions').insert(chunk);
      inserted += chunk.length;
    }
    return inserted;
  }

  /// Update existing transaction and recalibrate monthly budget spent_amount
  Future<TransactionModel> updateTransaction({
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
    // 1. Fetch old transaction before update
    final oldRes = await _client
        .from('pf_transactions')
        .select('category_id, type, amount, transaction_date')
        .eq('id', id)
        .single();

    final oldCatId = oldRes['category_id'] as String?;
    final oldType = TransactionType.fromString(oldRes['type'] as String);
    final oldAmount = (oldRes['amount'] as num).toInt();
    final oldDate = DateTime.parse(oldRes['transaction_date'] as String);

    // 2. Perform update
    final map = <String, dynamic>{
      'type': type.toDbString(),
      'amount': amount,
      'transaction_date': _date(transactionDate),
      'category_id': type == TransactionType.transfer ? null : categoryId,
      'wallet_id': walletId,
      'to_wallet_id': type == TransactionType.transfer ? toWalletId : null,
      'payment_method': paymentMethod,
      'merchant': merchant?.trim().isEmpty == true ? null : merchant?.trim(),
    };
    if (description != null) map['note'] = description.trim();

    final res = await _client
        .from('pf_transactions')
        .update(map)
        .eq('id', id)
        .select(kTransactionSelect)
        .single();

    final updatedTx = TransactionModel.fromJson(res);

    // 3. Recalibrate budget spent_amount
    if (oldType == TransactionType.expense && oldCatId != null) {
      await _adjustBudgetSpent(
        categoryId: oldCatId,
        month: oldDate.month,
        year: oldDate.year,
        delta: -oldAmount,
      );
    }
    if (type == TransactionType.expense && categoryId != null) {
      await _adjustBudgetSpent(
        categoryId: categoryId,
        month: transactionDate.month,
        year: transactionDate.year,
        delta: amount,
      );
    }

    return updatedTx;
  }

  /// Delete transaction and adjust budget spent_amount, with bi-directional cleanup
  Future<void> deleteTransaction(String id) async {
    // 1. Fetch transaction before deleting
    final txRes = await _client
        .from('pf_transactions')
        .select('category_id, type, amount, transaction_date, note')
        .eq('id', id)
        .maybeSingle();

    if (txRes != null) {
      final catId = txRes['category_id'] as String?;
      final typeStr = txRes['type'] as String;
      final amount = (txRes['amount'] as num).toInt();
      final date = DateTime.parse(txRes['transaction_date'] as String);
      final note = txRes['note'] as String?;

      // If it was an expense, subtract from monthly budget spent_amount
      if (typeStr == 'expense' && catId != null) {
        await _adjustBudgetSpent(
          categoryId: catId,
          month: date.month,
          year: date.year,
          delta: -amount,
        );
      }

      // Bi-directional sync: if linked to savings deposit (e.g. "Setor: ..."), clean up pf_savings_transactions
      if (note != null && note.startsWith('Setor:')) {
        try {
          final goalName = note.substring(6).split('(').first.trim();
          final goals = await _client
              .from('pf_savings_goals')
              .select('id, current_amount')
              .eq('user_id', _userId)
              .eq('name', goalName);

          for (final g in (goals as List)) {
            final gid = g['id'] as String;
            await _client
                .from('pf_savings_transactions')
                .delete()
                .eq('goal_id', gid)
                .eq('user_id', _userId)
                .eq('amount', amount);

            final cur = (g['current_amount'] as num?)?.toInt() ?? 0;
            final newCur = (cur - amount) > 0 ? (cur - amount) : 0;
            await _client
                .from('pf_savings_goals')
                .update({'current_amount': newCur})
                .eq('id', gid);
          }
        } catch (_) {}
      }

      // Bi-directional sync: if linked to debt payment
      if (note != null &&
          (note.contains('Cicilan') || note.contains('Bayar'))) {
        try {
          final payments = await _client
              .from('pf_debt_payments')
              .select('id, debt_id')
              .eq('user_id', _userId)
              .eq('amount', amount)
              .eq('payment_date', _date(date))
              .limit(1);
          for (final p in (payments as List)) {
            final pid = p['id'] as String;
            final did = p['debt_id'] as String;
            await _client
                .from('pf_debt_payments')
                .delete()
                .eq('id', pid)
                .eq('user_id', _userId);

            // Restore debt remaining_amount (kolom: initial_amount, status)
            final debtRes = await _client
                .from('pf_debts')
                .select('remaining_amount, initial_amount')
                .eq('id', did)
                .single();
            final curRem = (debtRes['remaining_amount'] as num).toInt();
            final totalAmt = (debtRes['initial_amount'] as num).toInt();
            final newRem = (curRem + amount) < totalAmt
                ? (curRem + amount)
                : totalAmt;
            await _client
                .from('pf_debts')
                .update({'remaining_amount': newRem, 'status': 'active'})
                .eq('id', did);
          }
        } catch (_) {}
      }
    }

    // 2. Delete from pf_transactions
    await _client
        .from('pf_transactions')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Transaksi pemasukan dengan catatan tertentu (mis. "Gaji Periode 11/2026").
  Future<TransactionModel?> findIncomeByNote(String note) async {
    final res = await _client
        .from('pf_transactions')
        .select(kTransactionSelect)
        .eq('user_id', _userId)
        .eq('type', 'income')
        .eq('note', note)
        .limit(1)
        .maybeSingle();
    return res == null ? null : TransactionModel.fromJson(res);
  }

  /// Lengkapi transaksi gaji dengan dompet tempat gaji benar-benar masuk.
  Future<void> setWallet(String id, String walletId) async {
    await _client
        .from('pf_transactions')
        .update({'wallet_id': walletId})
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Helper to safely increment or decrement budget spent_amount
  Future<void> _adjustBudgetSpent({
    required String categoryId,
    required int month,
    required int year,
    required int delta,
  }) async {
    final budgetRes = await _client
        .from('pf_monthly_budgets')
        .select('id, spent_amount')
        .eq('user_id', _userId)
        .eq('category_id', categoryId)
        .eq('period_month', month)
        .eq('period_year', year)
        .maybeSingle();

    if (budgetRes != null) {
      final currentSpent = (budgetRes['spent_amount'] as num?)?.toInt() ?? 0;
      final int newSpent = (currentSpent + delta) > 0
          ? (currentSpent + delta)
          : 0;
      await _client
          .from('pf_monthly_budgets')
          .update({'spent_amount': newSpent})
          .eq('id', budgetRes['id']);
    }
  }
}
