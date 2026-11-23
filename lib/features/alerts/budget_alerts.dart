// lib/features/alerts/budget_alerts.dart
//
// Peringatan budget real-time. Dicek setiap kali pengeluaran tersimpan
// (manual, dari notifikasi, AI, atau import satuan). Masing-masing ambang
// (80% dan 100%) hanya dikirim sekali per kategori per bulan.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/storage/local_store.dart';
import '../salary_allocation/domain/monthly_budget.dart';

class BudgetAlert {
  final String categoryName;
  final int percent;
  final int spent;
  final int allocated;

  const BudgetAlert({
    required this.categoryName,
    required this.percent,
    required this.spent,
    required this.allocated,
  });

  String get message => percent >= 100
      ? 'Budget $categoryName sudah habis (${_pct(spent, allocated)}% terpakai).'
      : 'Budget $categoryName sudah $percent%. Sisa ${_short(allocated - spent)}.';

  static int _pct(int a, int b) => b == 0 ? 0 : (a * 100 / b).round();
  static String _short(int v) {
    if (v >= 1000000) {
      return 'Rp${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    }
    if (v >= 1000) return 'Rp${(v / 1000).round()}rb';
    return 'Rp$v';
  }
}

/// Menentukan ambang yang baru saja dilewati. Fungsi murni supaya mudah dites.
int? crossedThreshold({
  required int before,
  required int after,
  required int allocated,
}) {
  if (allocated <= 0) return null;
  for (final t in const [100, 80]) {
    final limit = allocated * t / 100;
    if (after >= limit && before < limit) return t;
  }
  return null;
}

/// Cek budget kategori setelah pengeluaran sebesar [amount] tersimpan.
/// [budgetAfter] adalah budget kategori yang SUDAH termasuk pengeluaran ini.
Future<BudgetAlert?> checkBudgetAlert(
  Ref ref, {
  required MonthlyBudget? budgetAfter,
  required int amount,
}) async {
  final b = budgetAfter;
  if (b == null || b.allocatedAmount <= 0 || b.isSavings) return null;
  final t = crossedThreshold(
    before: b.spentAmount - amount,
    after: b.spentAmount,
    allocated: b.allocatedAmount,
  );
  if (t == null) return null;

  final store = ref.read(maybeLocalStoreProvider);
  final key =
      'budget_alert_${b.categoryId}_${b.periodYear}_${b.periodMonth}_$t';
  if (store?.getBool(key) == true) return null;
  await store?.setBool(key, true);

  final alert = BudgetAlert(
    categoryName: b.categoryName ?? 'kategori',
    percent: t,
    spent: b.spentAmount,
    allocated: b.allocatedAmount,
  );
  try {
    await NotificationService().showBudgetWarning(
      categoryName: alert.categoryName,
      spentAmount: alert.spent,
      budgetAmount: alert.allocated,
      percent: t,
    );
  } catch (_) {}
  return alert;
}

/// Pesan peringatan terakhir untuk ditampilkan sebagai snackbar di UI.
final lastBudgetAlertProvider = StateProvider<BudgetAlert?>((ref) => null);
