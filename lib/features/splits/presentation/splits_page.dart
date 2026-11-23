// lib/features/splits/presentation/splits_page.dart
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
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/widgets/pickers.dart';
import '../domain/split_bill.dart';
import 'providers/splits_provider.dart';

class SplitsPage extends ConsumerWidget {
  const SplitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(splitsProvider);
    final splits = async.value ?? const <SplitBill>[];
    final receivable = ref.watch(splitReceivableProvider);
    final open = splits.where((s) => !s.isSettled).toList();
    final done = splits.where((s) => s.isSettled).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(context, 'Patungan'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSplitSheet(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Patungan'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Belum dikembalikan teman',
                        style: Ui.body(size: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        receivable.toRupiah,
                        style: Ui.amount(size: 24, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bagianmu dicatat sebagai pengeluaran. Uang yang kamu talangi untuk teman tidak masuk budget, dan kembali ke dompet saat dilunasi.',
                        style: Ui.body(size: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (async.isLoading && splits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (splits.isEmpty)
                  const EmptyHint(
                    icon: Icons.groups_outlined,
                    title: 'Belum ada patungan',
                    message:
                        'Bayarin makan bareng atau tiket liburan? Catat di sini, lalu tandai lunas saat teman transfer balik.',
                  )
                else ...[
                  if (open.isNotEmpty) ...[
                    const SectionHeader('Belum lunas'),
                    for (final s in open) ...[
                      _SplitCard(bill: s),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (done.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const SectionHeader('Selesai'),
                    for (final s in done) ...[
                      _SplitCard(bill: s),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitCard extends ConsumerWidget {
  final SplitBill bill;
  const _SplitCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bill.title, style: Ui.title()),
                      const SizedBox(height: 2),
                      Text(
                        '${dateShortId(bill.splitDate)} · total ${bill.totalAmount.toRupiah} · bagianku ${bill.myShare.toRupiah}',
                        style: Ui.body(size: 12.5),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: AppTheme.textDarkMuted,
                  ),
                  onPressed: () async {
                    final ok = await showAppConfirm(
                      context: context,
                      title: 'Hapus patungan ini?',
                      message:
                          'Catatan piutang dihapus. Transaksi yang sudah tercatat tetap ada dan bisa dihapus dari halaman Transaksi.',
                      confirmLabel: 'Hapus',
                      destructive: true,
                    );
                    if (ok) {
                      await ref.read(splitsProvider.notifier).delete(bill);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final p in bill.participants)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.name,
                      style: Ui.body(
                        size: 14,
                        color: p.isSettled
                            ? AppTheme.textDarkMuted
                            : AppTheme.textDarkPrimary,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(
                    p.shareAmount.toRupiah,
                    style: Ui.amount(
                      size: 14,
                      color: p.isSettled
                          ? AppTheme.textDarkMuted
                          : AppTheme.textDarkPrimary,
                    ),
                  ))),
                  const SizedBox(width: 4),
                  p.isSettled
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Color(0xFF059669),
                          ),
                        )
                      : TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(splitsProvider.notifier)
                                  .settle(bill, p);
                              if (context.mounted) {
                                AppTheme.showSuccessSnackBar(
                                  context,
                                  '${p.name} lunas.',
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
                          child: const Text('Lunas'),
                        ),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

Future<void> showSplitSheet(BuildContext context, {String? title, int? total}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => _SplitSheet(title: title, total: total),
  );
}

class _SplitSheet extends ConsumerStatefulWidget {
  final String? title;
  final int? total;
  const _SplitSheet({this.title, this.total});
  @override
  ConsumerState<_SplitSheet> createState() => _SplitSheetState();
}

class _Person {
  final TextEditingController name;
  final TextEditingController share;
  _Person(String n, String s)
    : name = TextEditingController(text: n),
      share = TextEditingController(text: s);
  void dispose() {
    name.dispose();
    share.dispose();
  }
}

class _SplitSheetState extends ConsumerState<_SplitSheet> {
  late final _title = TextEditingController(text: widget.title ?? '');
  late final _total = TextEditingController(
    text: widget.total == null
        ? ''
        : CurrencyInputFormatter.format(widget.total!),
  );
  final _people = <_Person>[_Person('', '')];
  bool _even = true;
  String? _walletId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    for (final p in _people) {
      p.dispose();
    }
    super.dispose();
  }

  int get _totalValue => CurrencyInputFormatter.parse(_total.text);

  List<int> get _shares {
    if (_even) {
      return splitEvenly(_totalValue, _people.length + 1).skip(1).toList();
    }
    return [
      for (final p in _people) CurrencyInputFormatter.parse(p.share.text),
    ];
  }

  int get _myShare => _totalValue - _shares.fold(0, (a, b) => a + b);

  Future<void> _save() async {
    final title = _title.text.trim();
    final people = <({String name, int share})>[];
    final shares = _shares;
    for (var i = 0; i < _people.length; i++) {
      final n = _people[i].name.text.trim();
      if (n.isEmpty || shares[i] <= 0) continue;
      people.add((name: n, share: shares[i]));
    }
    if (title.isEmpty || _totalValue <= 0 || people.isEmpty) {
      setState(() => _error = 'Isi judul, total, dan minimal satu teman.');
      return;
    }
    if (_myShare < 0) {
      setState(() => _error = 'Bagian teman melebihi total.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(splitsProvider.notifier)
          .create(
            title: title,
            totalAmount: _totalValue,
            myShare: _myShare,
            date: _date,
            walletId: _walletId,
            categoryId: _categoryId,
            participants: people,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(
        () => _error = ErrorHelper.getHumanReadableMessage(
          e,
          fallback: 'Gagal menyimpan patungan.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shares = _shares;
    return AppModalScaffold(
      title: 'Patungan baru',
      subtitle: 'Kamu yang bayar dulu, teman mengganti belakangan.',
      actions: [
        AppModalScaffold.cancelButton(context),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Untuk apa',
              hintText: 'mis. Makan malam Sate Senayan',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _total,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 20),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Total yang kamu bayar',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 18),
          Segmented<bool>(
            items: const [(true, 'Bagi rata'), (false, 'Atur sendiri')],
            value: _even,
            onChanged: (v) => setState(() => _even = v),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _people.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _people[i].name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: 'Teman ${i + 1}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _even
                        ? InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Bagian',
                            ),
                            child: Text(
                              shares[i].toRupiah,
                              style: Ui.amount(size: 14),
                            ),
                          )
                        : TextField(
                            controller: _people[i].share,
                            keyboardType: TextInputType.number,
                            inputFormatters: [CurrencyInputFormatter()],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              labelText: 'Bagian',
                              prefixText: 'Rp ',
                            ),
                          ),
                  ),
                  if (_people.length > 1)
                    IconButton(
                      onPressed: () =>
                          setState(() => _people.removeAt(i).dispose()),
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        color: AppTheme.textDarkMuted,
                      ),
                    ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _people.add(_Person('', ''))),
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Tambah teman'),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bagianku',
                    style: Ui.body(size: 13.5, color: AppTheme.textDarkPrimary),
                  ),
                ),
                Text(
                  _myShare.toRupiah,
                  style: Ui.amount(
                    size: 15,
                    color: _myShare < 0
                        ? AppTheme.danger
                        : AppTheme.textDarkPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Kategori bagianku'),
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
          const SizedBox(height: 18),
          const AppFieldLabel('Tanggal'),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: Ui.body(size: 13, color: AppTheme.danger)),
          ],
        ],
      ),
    );
  }
}
