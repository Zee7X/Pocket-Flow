// lib/features/wallets/presentation/wallets_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/formatters/currency_input_formatter.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../../transactions/presentation/widgets/pickers.dart';
import '../domain/payment_providers.dart';
import '../domain/wallet.dart';
import 'providers/wallets_provider.dart';

class WalletsPage extends ConsumerWidget {
  const WalletsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(walletsProvider);
    final wallets = async.value ?? const <Wallet>[];
    final total = ref.watch(totalWalletBalanceProvider);
    final liabilities = wallets
        .where((w) => w.kind.isLiability)
        .fold<int>(0, (s, w) => s + w.balance);

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(
        context,
        'Dompet & Rekening',
        actions: [
          IconButton(
            tooltip: 'Transfer antar dompet',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: wallets.length < 2
                ? null
                : () => showTransferSheet(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWalletSheet(context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 1,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Dompet'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(walletsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                        Text('Total saldo', style: Ui.body(size: 13)),
                        const SizedBox(height: 4),
                        Text(
                          total.toRupiah,
                          style: Ui.amount(size: 26, weight: FontWeight.w700),
                        ),
                        if (liabilities != 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tagihan kartu kredit & paylater: ${liabilities.abs().toRupiah}',
                            style: Ui.body(size: 12.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (async.isLoading && wallets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (wallets.isEmpty)
                    EmptyHint(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Belum ada dompet',
                      message:
                          'Tambahkan GoPay, BCA, tunai, dan lainnya supaya saldo tiap akun terlihat dan transaksi dari notifikasi langsung masuk ke dompet yang benar.',
                      action: ElevatedButton(
                        onPressed: () => showWalletSheet(context),
                        child: const Text('Tambah dompet'),
                      ),
                    )
                  else
                    for (final kind in WalletKind.values)
                      if (wallets.any((w) => w.kind == kind)) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 8,
                            left: 4,
                          ),
                          child: Text(
                            kind.label,
                            style: Ui.body(size: 12.5, weight: FontWeight.w600),
                          ),
                        ),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (i, w)
                                  in wallets
                                      .where((w) => w.kind == kind)
                                      .indexed) ...[
                                if (i > 0) const Divider(height: 1, indent: 64),
                                ListRow(
                                  leading: IconBadge(
                                    w.kind.icon,
                                    color: w.displayColor,
                                  ),
                                  title: w.name,
                                  subtitle:
                                      (PaymentProviders.byKey(
                                            w.providerKey,
                                          )?.androidPackages.isNotEmpty ??
                                          false)
                                      ? 'Dicatat otomatis dari notifikasi'
                                      : null,
                                  trailing: Text(
                                    w.balance < 0
                                        ? '-${w.balance.abs().toRupiah}'
                                        : w.balance.toRupiah,
                                    style: Ui.amount(
                                      size: 14.5,
                                      color: w.balance < 0
                                          ? AppTheme.danger
                                          : AppTheme.textDarkPrimary,
                                    ),
                                  ),
                                  onTap: () =>
                                      showWalletSheet(context, wallet: w),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showWalletSheet(BuildContext context, {Wallet? wallet}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => _WalletSheet(wallet: wallet),
  );
}

class _WalletSheet extends ConsumerStatefulWidget {
  final Wallet? wallet;
  const _WalletSheet({this.wallet});

  @override
  ConsumerState<_WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends ConsumerState<_WalletSheet> {
  late final _name = TextEditingController(text: widget.wallet?.name ?? '');
  late final _balance = TextEditingController(
    text: widget.wallet == null
        ? ''
        : CurrencyInputFormatter.format(widget.wallet!.initialBalance.abs()),
  );
  late WalletKind _kind = widget.wallet?.kind ?? WalletKind.ewallet;
  late String? _provider = widget.wallet?.providerKey;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _pickPreset(PaymentProvider? p) {
    setState(() {
      _provider = p?.key;
      if (p != null) {
        _kind = p.kind;
        if (_name.text.trim().isEmpty ||
            PaymentProviders.all.any((x) => x.name == _name.text.trim())) {
          _name.text = p.name;
        }
      }
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    var initial = CurrencyInputFormatter.parse(_balance.text);
    if (_kind.isLiability) initial = -initial; // tagihan awal = saldo negatif
    final color = PaymentProviders.byKey(_provider)?.color;
    setState(() => _busy = true);
    try {
      final n = ref.read(walletsProvider.notifier);
      if (widget.wallet == null) {
        await n.addWallet(
          name: name,
          kind: _kind,
          providerKey: _provider,
          initialBalance: initial,
          color: color == null ? null : colorToHex(color),
        );
      } else {
        await n.updateWallet(
          id: widget.wallet!.id,
          name: name,
          kind: _kind,
          providerKey: _provider,
          initialBalance: initial,
          color: color == null ? widget.wallet!.color : colorToHex(color),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menyimpan dompet.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final ok = await showAppConfirm(
      context: context,
      title: 'Arsipkan ${widget.wallet!.name}?',
      message:
          'Dompet disembunyikan dari daftar. Riwayat transaksinya tetap tersimpan.',
      confirmLabel: 'Arsipkan',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(walletsProvider.notifier).archiveWallet(widget.wallet!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final presets = PaymentProviders.all;
    final isEdit = widget.wallet != null;
    return AppModalScaffold(
      title: isEdit ? 'Ubah dompet' : 'Dompet baru',
      actions: [
        isEdit
            ? OutlinedButton(
                onPressed: _archive,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                ),
                child: const Text('Arsipkan'),
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
          const AppFieldLabel('Pilih penyedia'),
          ChoiceChips<String>(
            values: [for (final p in presets) p.key],
            selected: _provider,
            label: (k) => PaymentProviders.byKey(k)!.name,
            onChanged: (k) => _pickPreset(PaymentProviders.byKey(k)),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama dompet',
              hintText: 'mis. BCA Gaji',
            ),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Jenis'),
          ChoiceChips<WalletKind>(
            values: WalletKind.values,
            selected: _kind,
            allowDeselect: false,
            label: (k) => k.label,
            onChanged: (k) => setState(() => _kind = k ?? _kind),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _balance,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 18),
            decoration: InputDecoration(
              labelText: _kind.isLiability ? 'Tagihan saat ini' : 'Saldo awal',
              prefixText: 'Rp ',
              helperText:
                  'Saldo sebelum transaksi pertama yang dicatat di PocketFlow.',
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTransferSheet(BuildContext context) {
  return showAppModal<void>(
    context: context,
    builder: (_) => const _TransferSheet(),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet();
  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _amount = TextEditingController();
  String? _from;
  String? _to;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = CurrencyInputFormatter.parse(_amount.text);
    if (amount <= 0 || _from == null || _to == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(transactionsProvider.notifier)
          .addTransaction(
            type: TransactionType.transfer,
            amount: amount,
            transactionDate: _date,
            description: 'Transfer antar dompet',
            walletId: _from,
            toWalletId: _to,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(
            e,
            fallback: 'Gagal menyimpan transfer.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalScaffold(
      title: 'Transfer antar dompet',
      subtitle: 'Tidak dihitung sebagai pengeluaran atau pemasukan.',
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
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [CurrencyInputFormatter()],
            style: Ui.amount(size: 22),
            decoration: const InputDecoration(
              labelText: 'Nominal',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Dari'),
          WalletPicker(
            value: _from,
            onChanged: (v) => setState(() => _from = v),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Ke'),
          WalletPicker(
            value: _to,
            excludeId: _from,
            onChanged: (v) => setState(() => _to = v),
          ),
          const SizedBox(height: 18),
          const AppFieldLabel('Tanggal'),
          DateField(value: _date, onChanged: (d) => setState(() => _date = d)),
        ],
      ),
    );
  }
}
