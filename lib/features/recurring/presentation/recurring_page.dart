// lib/features/recurring/presentation/recurring_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/formatters/currency_input_formatter.dart';
import '../../../core/utils/date_id.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../debts_savings/presentation/providers/debts_savings_provider.dart';
import '../../smart/domain/category_suggester.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/widgets/pickers.dart';
import '../domain/recurring_bill.dart';
import 'providers/recurring_provider.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recurringBillsProvider);
    final bills = async.value ?? const <RecurringBill>[];
    final suggestions = ref.watch(recurringSuggestionsProvider);
    final monthly = bills.fold<int>(0, (s, b) => s + b.monthlyCost);
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(context, 'Langganan & Tagihan'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBillSheet(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tagihan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total per bulan', style: Ui.body(size: 13)),
                            const SizedBox(height: 4),
                            Text(
                              monthly.toRupiah,
                              style: Ui.amount(
                                size: 24,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${bills.length} tagihan aktif',
                        style: Ui.body(size: 12.5),
                      ),
                    ],
                  ),
                ),
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader('Terdeteksi dari riwayat'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, s) in suggestions.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: Ui.body(
                                          size: 14,
                                          color: AppTheme.textDarkPrimary,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s.amount.toRupiah} · ${s.occurrences}x · berikutnya ${dateRelativeId(s.nextDueDate)}',
                                        style: Ui.body(size: 12.5),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(dismissedRecurringProvider.notifier)
                                      .dismiss(s.merchantKey),
                                  child: const Text('Bukan'),
                                ),
                                TextButton(
                                  onPressed: () => ref
                                      .read(recurringBillsProvider.notifier)
                                      .save(
                                        name: s.name,
                                        amount: s.amount,
                                        categoryId: s.categoryId,
                                        walletId: s.walletId,
                                        cadence: BillCadence.monthly,
                                        nextDueDate: s.nextDueDate,
                                        merchantKey: s.merchantKey,
                                      ),
                                  child: const Text('Tambahkan'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const SectionHeader('Jadwal'),
                if (async.isLoading && bills.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (bills.isEmpty)
                  const EmptyHint(
                    icon: Icons.event_repeat_outlined,
                    title: 'Belum ada tagihan rutin',
                    message:
                        'Catat Netflix, Spotify, internet, kos, atau cicilan paylater. PocketFlow akan mengingatkan sebelum jatuh tempo.',
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, b) in bills.indexed) ...[
                          if (i > 0) const Divider(height: 1, indent: 16),
                          _BillRow(bill: b, now: now),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends ConsumerWidget {
  final RecurringBill bill;
  final DateTime now;
  const _BillRow({required this.bill, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = bill.daysUntilDue(now);
    final dueLabel = days < 0
        ? 'Lewat ${-days} hari'
        : days == 0
        ? 'Jatuh tempo hari ini'
        : days == 1
        ? 'Besok'
        : '$days hari lagi · ${dateShortId(bill.nextDueDate)}';
    final urgent = days <= 2;
    return InkWell(
      onTap: () => showBillSheet(context, bill: bill),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: Ui.body(
                      size: 14,
                      color: AppTheme.textDarkPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bill.amount.toRupiah} · ${bill.cadence.label}',
                    style: Ui.body(size: 12.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dueLabel,
                    style: Ui.body(
                      size: 12.5,
                      color: urgent
                          ? AppTheme.danger
                          : AppTheme.textDarkSecondary,
                      weight: urgent ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(recurringBillsProvider.notifier)
                      .markPaid(bill);
                  if (context.mounted) {
                    AppTheme.showSuccessSnackBar(
                      context,
                      '${bill.name} dicatat lunas.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    AppTheme.showErrorSnackBar(
                      context,
                      ErrorHelper.getHumanReadableMessage(
                        e,
                        fallback: 'Gagal mencatat.',
                      ),
                    );
                  }
                }
              },
              child: const Text('Sudah bayar'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showBillSheet(BuildContext context, {RecurringBill? bill}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => _BillSheet(bill: bill),
  );
}

class _BillSheet extends ConsumerStatefulWidget {
  final RecurringBill? bill;
  const _BillSheet({this.bill});
  @override
  ConsumerState<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends ConsumerState<_BillSheet> {
  late final _name = TextEditingController(text: widget.bill?.name ?? '');
  late final _amount = TextEditingController(
    text: widget.bill == null
        ? ''
        : CurrencyInputFormatter.format(widget.bill!.amount),
  );
  late BillCadence _cadence = widget.bill?.cadence ?? BillCadence.monthly;
  late DateTime _due =
      widget.bill?.nextDueDate ?? DateTime.now().add(const Duration(days: 7));
  late String? _categoryId = widget.bill?.categoryId;
  late String? _walletId = widget.bill?.walletId;
  late String? _debtId = widget.bill?.debtId;
  late int _remind = widget.bill?.remindDaysBefore ?? 2;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = CurrencyInputFormatter.parse(_amount.text);
    if (name.isEmpty || amount <= 0) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(recurringBillsProvider.notifier)
          .save(
            id: widget.bill?.id,
            name: name,
            amount: amount,
            categoryId: _categoryId,
            walletId: _walletId,
            debtId: _debtId,
            cadence: _cadence,
            nextDueDate: _due,
            remindDaysBefore: _remind,
            merchantKey: widget.bill?.merchantKey ?? merchantKey(name),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menyimpan tagihan.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showAppConfirm(
      context: context,
      title: 'Hapus ${widget.bill!.name}?',
      message:
          'Pengingat untuk tagihan ini juga dihapus. Transaksi yang sudah dicatat tidak terhapus.',
      confirmLabel: 'Hapus',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(recurringBillsProvider.notifier).remove(widget.bill!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final debts = (ref.watch(debtsProvider).value ?? const [])
        .where((d) => !d.isPaid)
        .toList();
    return AppModalScaffold(
      title: widget.bill == null ? 'Tagihan rutin baru' : 'Ubah tagihan',
      actions: [
        widget.bill != null
            ? OutlinedButton(
                onPressed: _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                ),
                child: const Text('Hapus'),
              )
            : AppModalScaffold.cancelButton(context),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama',
              hintText: 'mis. Netflix, IndiHome, SPayLater',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 18),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Berulang'),
          Segmented<BillCadence>(
            items: [for (final c in BillCadence.values) (c, c.label)],
            value: _cadence,
            onChanged: (c) => setState(() => _cadence = c),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Jatuh tempo berikutnya'),
          DateField(
            value: _due,
            lastDate: DateTime.now().add(const Duration(days: 400)),
            onChanged: (d) => setState(() => _due = d),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Ingatkan'),
          ChoiceChips<int>(
            values: const [0, 1, 2, 3, 7],
            selected: _remind,
            allowDeselect: false,
            label: (d) => d == 0 ? 'Hari H' : '$d hari sebelum',
            onChanged: (d) => setState(() => _remind = d ?? _remind),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Kategori'),
          CategoryPicker(
            type: TransactionType.expense,
            value: _categoryId,
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Dibayar dari'),
          WalletPicker(
            value: _walletId,
            onChanged: (v) => setState(() => _walletId = v),
          ),
          if (debts.isNotEmpty) ...[
            const SizedBox(height: 18),
            const AppFieldLabel('Cicilan untuk utang (opsional)'),
            ChoiceChips<String>(
              values: [for (final d in debts) d.id],
              selected: _debtId,
              label: (id) => debts.firstWhere((d) => d.id == id).name,
              onChanged: (v) => setState(() => _debtId = v),
            ),
            const SizedBox(height: 6),
            Text(
              'Saat ditandai sudah bayar, sisa utang otomatis berkurang.',
              style: Ui.body(size: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
