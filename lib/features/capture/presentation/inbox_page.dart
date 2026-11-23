// lib/features/capture/presentation/inbox_page.dart
//
// "Perlu Ditinjau": transaksi yang terdeteksi otomatis dari notifikasi,
// struk, shortcut, atau teks yang ditempel.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/utils/date_id.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../smart/domain/quick_text_parser.dart';
import '../../smart/presentation/widgets/draft_editor_sheet.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/presentation/providers/wallets_provider.dart';
import '../domain/pending_capture.dart';
import 'providers/capture_provider.dart';
import 'widgets/paste_capture_sheet.dart';

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingCapturesProvider);
    final items = async.value ?? const <PendingCapture>[];
    final readyCount = items
        .where(
          (p) =>
              p.type == TransactionType.transfer ||
              p.suggestedCategoryId != null,
        )
        .length;

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(
        context,
        'Perlu Ditinjau',
        actions: [
          IconButton(
            tooltip: 'Pengaturan deteksi',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/capture-settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(pendingCapturesProvider.notifier).drainNative();
          ref.invalidate(pendingCapturesProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            ResponsiveCenter(
              maxWidth: 720,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Transaksi yang terbaca dari notifikasi aplikasi pembayaran, struk, atau shortcut. '
                    'Periksa nominal dan kategorinya, lalu simpan.',
                    style: Ui.body(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showPasteCaptureSheet(context),
                          icon: const Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                          ),
                          label: const Text('Tempel teks'),
                        ),
                      ),
                      if (readyCount > 1) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final n = await ref
                                  .read(pendingCapturesProvider.notifier)
                                  .confirmAllReady();
                              if (context.mounted) {
                                AppTheme.showSuccessSnackBar(
                                  context,
                                  '$n transaksi disimpan.',
                                );
                              }
                            },
                            child: Text('Simpan $readyCount siap'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (async.isLoading && items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (items.isEmpty)
                    const EmptyHint(
                      icon: Icons.inbox_outlined,
                      title: 'Belum ada yang perlu ditinjau',
                      message:
                          'Transaksi dari GoPay, OVO, DANA, bank, dan lainnya akan muncul di sini begitu notifikasinya masuk.',
                    )
                  else
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < items.length; i++) ...[
                            if (i > 0) const Divider(height: 1, indent: 64),
                            _InboxRow(item: items[i]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxRow extends ConsumerWidget {
  final PendingCapture item;
  const _InboxRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final cat = cats.where((c) => c.id == item.suggestedCategoryId).firstOrNull;
    final wallet = wallets
        .where((w) => w.id == item.suggestedWalletId)
        .firstOrNull;
    final toWallet = wallets.where((w) => w.id == item.toWalletId).firstOrNull;

    final isIncome = item.type == TransactionType.income;
    final isTransfer = item.type == TransactionType.transfer;
    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : (isIncome ? Icons.south_west_rounded : Icons.north_east_rounded);
    final color = isTransfer
        ? AppTheme.primary
        : (isIncome ? const Color(0xFF059669) : AppTheme.textDarkSecondary);

    final title = isTransfer
        ? '${wallet?.name ?? '?'} → ${toWallet?.name ?? '?'}'
        : (item.merchant ?? (isIncome ? 'Uang masuk' : 'Pembayaran'));
    final meta = [
      item.sourceApp ?? item.sourceLabel,
      '${dateRelativeId(item.occurredAt)} ${timeId(item.occurredAt)}',
    ].join(' · ');

    return InkWell(
      onTap: () => _review(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ui.body(
                            size: 14,
                            color: AppTheme.textDarkPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MoneyText(
                        item.amount,
                        isIncome: isTransfer ? null : isIncome,
                        showSign: !isTransfer,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(meta, style: Ui.body(size: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTransfer
                              ? 'Transfer antar dompet'
                              : (cat == null
                                    ? 'Kategori belum dipilih'
                                    : cat.name),
                          style: Ui.body(
                            size: 12.5,
                            color: cat == null && !isTransfer
                                ? AppTheme.warning
                                : AppTheme.textDarkPrimary,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _SmallButton(
                        label: 'Abaikan',
                        onTap: () => ref
                            .read(pendingCapturesProvider.notifier)
                            .dismiss(item),
                      ),
                      const SizedBox(width: 4),
                      _SmallButton(
                        label: cat == null && !isTransfer ? 'Tinjau' : 'Simpan',
                        primary: true,
                        onTap: () => cat == null && !isTransfer
                            ? _review(context, ref)
                            : _save(context, ref, null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    final edited = await showDraftEditor(
      context,
      title: 'Tinjau transaksi',
      subtitle: 'Terbaca dari ${item.sourceApp ?? item.sourceLabel}',
      draft: DraftTransaction(
        type: item.type,
        amount: item.amount,
        merchant: item.merchant,
        date: item.occurredAt,
        providerKey: item.providerKey,
        categoryId: item.suggestedCategoryId,
        walletId: item.suggestedWalletId,
        toWalletId: item.toWalletId,
      ),
    );
    if (edited != null && context.mounted) await _save(context, ref, edited);
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    DraftTransaction? d,
  ) async {
    try {
      await ref
          .read(pendingCapturesProvider.notifier)
          .confirm(
            item,
            type: d?.type ?? item.type,
            amount: d?.amount ?? item.amount,
            date: d?.date ?? item.occurredAt,
            categoryId: d == null ? item.suggestedCategoryId : d.categoryId,
            walletId: d == null ? item.suggestedWalletId : d.walletId,
            toWalletId: d == null ? item.toWalletId : d.toWalletId,
            merchant: d == null ? item.merchant : d.merchant,
          );
      if (context.mounted) {
        AppTheme.showSuccessSnackBar(
          context,
          '${(d?.amount ?? item.amount).toRupiah} tersimpan.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppTheme.showErrorSnackBar(
          context,
          ErrorHelper.getHumanReadableMessage(e, fallback: 'Gagal menyimpan.'),
        );
      }
    }
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _SmallButton({
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: primary
            ? AppTheme.primary
            : AppTheme.textDarkSecondary,
        backgroundColor: primary
            ? AppTheme.primary.withValues(alpha: 0.08)
            : null,
      ),
      child: Text(label),
    );
  }
}
