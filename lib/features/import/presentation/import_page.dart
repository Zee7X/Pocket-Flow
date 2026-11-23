// lib/features/import/presentation/import_page.dart
//
// Import transaksi dari Money Manager, Money Lover, Wallet, atau file CSV /
// Excel lain. Langkah: pilih file → cek pemetaan kolom, kategori, dompet →
// import. Baris yang sudah pernah diimpor otomatis dilewati.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/utils/date_id.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../categories_rules/domain/category.dart';
import '../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../../wallets/domain/payment_providers.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/providers/wallets_provider.dart';
import '../data/import_file_reader.dart';
import '../domain/import_parser.dart';

const _createNew = '__new__';
const _skip = '__skip__';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});
  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  String? _fileName;
  ImportTable? _table;
  ImportAnalysis? _analysis;
  Map<ImportColumn, int>? _mapping;
  final Map<String, String> _catMap =
      {}; // "type|name" -> categoryId / _createNew
  final Map<String, String> _walletMap =
      {}; // accountName -> walletId / _createNew / _skip
  bool _busy = false;
  String? _error;
  String? _done;
  double _progress = 0;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _done = null;
    });
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'txt'],
    );
    if (f == null) return;
    try {
      final bytes = await f.xFile.readAsBytes();
      final table = ImportFileReader.read(f.name, bytes);
      if (table.headers.isEmpty) {
        throw const FormatException('File kosong atau tidak terbaca.');
      }
      setState(() {
        _fileName = f.name;
        _table = table;
        _mapping = null;
      });
      _reanalyze();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'File tidak bisa dibaca: $e');
    }
  }

  void _reanalyze() {
    final t = _table;
    if (t == null) return;
    final a = ImportParser.analyze(t, mapping: _mapping);
    final cats = ref.read(categoriesProvider).value ?? const <Category>[];
    final wallets = ref.read(walletsProvider).value ?? const <Wallet>[];
    _catMap.clear();
    _walletMap.clear();
    for (final r in a.rows) {
      if (r.category != null && r.type != TransactionType.transfer) {
        final key = '${r.type.name}|${r.category}';
        _catMap.putIfAbsent(key, () {
          final want = r.type == TransactionType.income
              ? CategoryType.income
              : CategoryType.expense;
          final match = cats
              .where(
                (c) =>
                    c.type == want &&
                    c.name.toLowerCase() == r.category!.toLowerCase(),
              )
              .firstOrNull;
          return match?.id ?? _createNew;
        });
      }
      for (final acc in [r.account, r.toAccount].whereType<String>()) {
        _walletMap.putIfAbsent(acc, () {
          final match = wallets
              .where((w) => w.name.toLowerCase() == acc.toLowerCase())
              .firstOrNull;
          return match?.id ?? _createNew;
        });
      }
    }
    setState(() {
      _analysis = a;
      _mapping = a.mapping;
    });
  }

  Future<void> _import() async {
    final a = _analysis;
    if (a == null || a.rows.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0.05;
    });
    try {
      // 1. Kategori baru
      final catIds = <String, String>{};
      final catsNotifier = ref.read(categoriesProvider.notifier);
      for (final e in _catMap.entries) {
        if (e.value != _createNew) {
          catIds[e.key] = e.value;
          continue;
        }
        final parts = e.key.split('|');
        final c = await catsNotifier.addCategory(
          name: parts.sublist(1).join('|'),
          type: parts.first == 'income'
              ? CategoryType.income
              : CategoryType.expense,
        );
        catIds[e.key] = c.id;
      }
      setState(() => _progress = 0.25);

      // 2. Dompet baru
      final walletIds = <String, String?>{};
      final wn = ref.read(walletsProvider.notifier);
      for (final e in _walletMap.entries) {
        if (e.value == _skip) {
          walletIds[e.key] = null;
        } else if (e.value == _createNew) {
          final p = PaymentProviders.byText(e.key);
          final w = await wn.addWallet(
            name: e.key,
            kind:
                p?.kind ??
                (e.key.toLowerCase().contains('cash') ||
                        e.key.toLowerCase().contains('tunai')
                    ? WalletKind.cash
                    : WalletKind.other),
            providerKey: p?.key,
            color: p == null ? null : colorToHex(p.color),
          );
          walletIds[e.key] = w.id;
        } else {
          walletIds[e.key] = e.value;
        }
      }
      setState(() => _progress = 0.4);

      // 3. Transaksi
      final now = DateTime.now();
      final items = [
        for (final r in a.rows)
          TransactionModel(
            id: '',
            userId: '',
            type: r.type,
            amount: r.amount,
            transactionDate: r.date,
            description: r.note ?? r.category,
            merchant: r.note,
            categoryId: r.category == null
                ? null
                : catIds['${r.type.name}|${r.category}'],
            walletId: r.account == null ? null : walletIds[r.account],
            toWalletId: r.toAccount == null ? null : walletIds[r.toAccount],
            source: 'import',
            externalRef: r.externalRef,
            createdAt: now,
          ),
      ];
      final n = await ref.read(transactionsProvider.notifier).addMany(items);
      setState(() {
        _progress = 1;
        _done = n == items.length
            ? '$n transaksi berhasil diimpor.'
            : '$n transaksi diimpor. ${items.length - n} dilewati karena sudah pernah diimpor.';
        _table = null;
        _analysis = null;
      });
    } catch (e) {
      setState(
        () => _error = ErrorHelper.getHumanReadableMessage(
          e,
          fallback: 'Import gagal.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _analysis;
    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(context, 'Import dari aplikasi lain'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (a == null) ..._intro(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: Ui.body(size: 13.5, color: AppTheme.danger),
                  ),
                ],
                if (_done != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Row(
                      children: [
                        const IconBadge(
                          Icons.check_rounded,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _done!,
                            style: Ui.body(
                              size: 14,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (a != null) ..._review(a),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _intro() => [
    Text(
      'Pindahkan riwayat dari aplikasi keuangan lama. Export datanya dulu, lalu pilih filenya di sini.',
      style: Ui.body(),
    ),
    const SizedBox(height: 16),
    AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          ListRow(
            title: 'Money Manager (Realbyte)',
            subtitle:
                'Lainnya → Backup → Export ke Excel. Kirim file .xlsx ke HP ini atau buka di browser.',
          ),
          Divider(height: 1),
          ListRow(
            title: 'Money Lover',
            subtitle:
                'Menu → Tools → Export CSV. Pemisah apa saja (koma, titik koma, tab) bisa dibaca.',
          ),
          Divider(height: 1),
          ListRow(
            title: 'Wallet, Spendee, Excel, Google Sheets',
            subtitle:
                'File .csv atau .xlsx dengan kolom tanggal dan nominal. Kolom lain bisa dipetakan manual.',
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    ElevatedButton.icon(
      onPressed: _pick,
      icon: const Icon(Icons.upload_file_rounded),
      label: const Text('Pilih file CSV / Excel'),
    ),
  ];

  List<Widget> _review(ImportAnalysis a) {
    final cats = ref.watch(categoriesProvider).value ?? const <Category>[];
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final headers = _table?.headers ?? const <String>[];
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_fileName ?? '', style: Ui.title()),
            const SizedBox(height: 4),
            Text(
              'Format terdeteksi: ${a.format.label}',
              style: Ui.body(size: 12.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _Stat('Transaksi', '${a.rows.length}'),
                _Stat('Pemasukan', a.totalIncome.toRupiah),
                _Stat('Pengeluaran', a.totalExpense.toRupiah),
                if (a.firstDate != null)
                  _Stat(
                    'Periode',
                    '${dateShortId(a.firstDate!)} – ${dateShortId(a.lastDate!)}',
                  ),
              ],
            ),
            if (a.skipped > 0) ...[
              const SizedBox(height: 10),
              Text(
                '${a.skipped} baris dilewati (tanpa tanggal/nominal, atau sisi masuk dari transfer).',
                style: Ui.body(size: 12.5),
              ),
            ],
            for (final w in a.warnings) ...[
              const SizedBox(height: 6),
              Text(w, style: Ui.body(size: 12.5, color: AppTheme.warning)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SectionHeader('Kolom'),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final col in const [
              ImportColumn.date,
              ImportColumn.amount,
              ImportColumn.type,
              ImportColumn.category,
              ImportColumn.note,
              ImportColumn.account,
            ])
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        col.label,
                        style: Ui.body(
                          size: 13.5,
                          color: AppTheme.textDarkPrimary,
                        ),
                      ),
                    ),
                    DropdownButton<int>(
                      value: _mapping?[col] ?? -1,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(value: -1, child: Text('—')),
                        for (var i = 0; i < headers.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              headers[i].isEmpty
                                  ? 'Kolom ${i + 1}'
                                  : headers[i],
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        final m = {...?_mapping};
                        if (v == null || v < 0) {
                          m.remove(col);
                        } else {
                          m[col] = v;
                        }
                        _mapping = m;
                        _reanalyze();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      if (_catMap.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionHeader('Kategori (${_catMap.length})'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final key in _catMap.keys)
                () {
                  final isIncome = key.startsWith('income|');
                  final name = key.split('|').sublist(1).join('|');
                  final options = cats
                      .where(
                        (c) => isIncome
                            ? c.type == CategoryType.income
                            : c.type != CategoryType.income,
                      )
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${isIncome ? '↓ ' : ''}$name',
                            style: Ui.body(
                              size: 13.5,
                              color: AppTheme.textDarkPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppTheme.textDarkMuted,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _catMap[key],
                            underline: const SizedBox.shrink(),
                            items: [
                              const DropdownMenuItem(
                                value: _createNew,
                                child: Text('Buat baru'),
                              ),
                              for (final c in options)
                                DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _catMap[key] = v ?? _createNew),
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
            ],
          ),
        ),
      ],
      if (_walletMap.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionHeader('Dompet (${_walletMap.length})'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final acc in _walletMap.keys)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          acc,
                          style: Ui.body(
                            size: 13.5,
                            color: AppTheme.textDarkPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppTheme.textDarkMuted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _walletMap[acc],
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem(
                              value: _createNew,
                              child: Text('Buat baru'),
                            ),
                            const DropdownMenuItem(
                              value: _skip,
                              child: Text('Tanpa dompet'),
                            ),
                            for (final w in wallets)
                              DropdownMenuItem(
                                value: w.id,
                                child: Text(
                                  w.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => _walletMap[acc] = v ?? _createNew),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      const SectionHeader('Contoh baris'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, r) in a.rows.take(6).indexed) ...[
              if (i > 0) const Divider(height: 1),
              ListRow(
                title:
                    r.note ??
                    r.category ??
                    (r.type == TransactionType.transfer ? 'Transfer' : '-'),
                subtitle: [
                  dateShortId(r.date),
                  ?r.category,
                  ?r.account,
                ].join(' · '),
                trailing: MoneyText(
                  r.amount,
                  isIncome: r.type == TransactionType.transfer
                      ? null
                      : r.type == TransactionType.income,
                  showSign: r.type != TransactionType.transfer,
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (_busy) ...[
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 12),
      ],
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _pick,
              child: const Text('Ganti file'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _busy || a.rows.isEmpty ? null : _import,
              child: Text('Import ${a.rows.length} transaksi'),
            ),
          ),
        ],
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Ui.body(size: 12)),
      const SizedBox(height: 2),
      Text(value, style: Ui.amount(size: 14.5)),
    ],
  );
}
