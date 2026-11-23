// lib/features/transactions/presentation/widgets/pickers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/date_id.dart';
import '../../../../core/widgets/ui.dart';
import '../../../categories_rules/domain/category.dart';
import '../../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../../wallets/domain/wallet.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../domain/transaction.dart';

/// Chip kategori sesuai jenis transaksi.
class CategoryPicker extends ConsumerWidget {
  final TransactionType type;
  final String? value;
  final ValueChanged<String?> onChanged;

  const CategoryPicker({
    super.key,
    required this.type,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final wanted = type == TransactionType.income
        ? [CategoryType.income]
        : [CategoryType.expense, CategoryType.savings, CategoryType.debt];
    final cats = all.where((c) => wanted.contains(c.type)).toList();
    if (cats.isEmpty) {
      return Text(
        'Belum ada kategori. Tambahkan di menu Aturan & Kategori.',
        style: Ui.body(size: 12.5),
      );
    }
    return ChoiceChips<String>(
      values: [for (final c in cats) c.id],
      selected: value,
      label: (id) => cats.firstWhere((c) => c.id == id).name,
      onChanged: onChanged,
    );
  }
}

/// Chip dompet. [excludeId] dipakai untuk dompet tujuan transfer.
class WalletPicker extends ConsumerWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? excludeId;

  const WalletPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.excludeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = (ref.watch(walletsProvider).value ?? const <Wallet>[])
        .where((w) => w.id != excludeId)
        .toList();
    if (wallets.isEmpty) {
      return Text(
        'Belum ada dompet. Tambahkan di menu Dompet supaya saldo per akun tercatat.',
        style: Ui.body(size: 12.5),
      );
    }
    return ChoiceChips<String>(
      values: [for (final w in wallets) w.id],
      selected: value,
      label: (id) => wallets.firstWhere((w) => w.id == id).name,
      icon: (id) => wallets.firstWhere((w) => w.id == id).kind.icon,
      onChanged: onChanged,
    );
  }
}

/// Tombol tanggal ringkas.
class DateField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? lastDate;

  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(value.year, value.month, value.day);
    final label = d == today
        ? 'Hari ini'
        : d == today.subtract(const Duration(days: 1))
        ? 'Kemarin'
        : dateLongId(value);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        side: const BorderSide(color: Ui.border),
      ),
      onPressed: () async {
        final last = lastDate ?? DateTime(now.year, now.month + 12, now.day);
        final picked = await showDatePicker(
          context: context,
          initialDate: value.isAfter(last) ? last : value,
          firstDate: DateTime(2015),
          lastDate: last,
        );
        if (picked != null) onChanged(picked);
      },
      icon: const Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: AppTheme.textDarkSecondary,
      ),
      label: Text(
        label,
        style: Ui.body(size: 14, color: AppTheme.textDarkPrimary),
      ),
    );
  }
}
