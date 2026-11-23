// lib/features/more/more_page.dart
//
// Menu "Lainnya": semua fitur pendukung dalam satu tempat.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/extensions/currency_extension.dart';
import '../../core/widgets/app_modal.dart';
import '../../core/widgets/responsive_center.dart';
import '../../core/widgets/ui.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../capture/presentation/providers/capture_provider.dart';
import '../recurring/presentation/providers/recurring_provider.dart';
import '../splits/presentation/providers/splits_provider.dart';
import '../transactions/presentation/providers/transactions_provider.dart';
import '../wallets/presentation/providers/wallets_provider.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountProvider);
    final walletTotal = ref.watch(totalWalletBalanceProvider);
    final walletCount = ref.watch(walletsProvider).value?.length ?? 0;
    final bills = ref.watch(recurringBillsProvider).value?.length ?? 0;
    final receivable = ref.watch(splitReceivableProvider);
    final unsynced = ref.watch(pendingSyncCountProvider);

    Widget row(
      IconData icon,
      String title,
      String? sub,
      String route, {
      Color? color,
      Widget? trailing,
    }) => ListRow(
      leading: IconBadge(icon, color: color ?? AppTheme.primary),
      title: title,
      subtitle: sub,
      trailing:
          trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textDarkMuted,
          ),
      onTap: () => context.push(route),
    );

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(context, 'Lainnya'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Pencatatan otomatis'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      row(
                        Icons.inbox_outlined,
                        'Perlu Ditinjau',
                        pending == 0
                            ? 'Tidak ada yang menunggu'
                            : '$pending transaksi menunggu',
                        AppRoutes.inbox,
                        trailing: pending == 0 ? null : _Count(pending),
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.notifications_active_outlined,
                        'Deteksi dari notifikasi',
                        'GoPay, OVO, DANA, bank, SMS bank',
                        AppRoutes.captureSettings,
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.upload_file_outlined,
                        'Import dari aplikasi lain',
                        'Money Manager, Money Lover, CSV, Excel',
                        AppRoutes.import,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader('Keuangan'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      row(
                        Icons.account_balance_wallet_outlined,
                        'Dompet & Rekening',
                        walletCount == 0
                            ? 'Belum ada dompet'
                            : '$walletCount dompet · ${walletTotal.toRupiah}',
                        AppRoutes.wallets,
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.event_repeat_outlined,
                        'Langganan & Tagihan',
                        bills == 0
                            ? 'Pengingat jatuh tempo'
                            : '$bills tagihan aktif',
                        AppRoutes.bills,
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.groups_outlined,
                        'Patungan',
                        receivable == 0
                            ? 'Split bill dengan teman'
                            : 'Piutang ${receivable.toRupiah}',
                        AppRoutes.splits,
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.insert_chart_outlined_rounded,
                        'Laporan & Insight',
                        'Ringkasan bulanan',
                        AppRoutes.reports,
                      ),
                      const Divider(height: 1, indent: 64),
                      row(
                        Icons.tune_rounded,
                        'Aturan & Kategori',
                        'Alokasi gaji dan daftar kategori',
                        AppRoutes.categoriesRules,
                      ),
                    ],
                  ),
                ),
                if (unsynced > 0) ...[
                  const SizedBox(height: 24),
                  AppCard(
                    child: Row(
                      children: [
                        const IconBadge(
                          Icons.cloud_off_outlined,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$unsynced transaksi dibuat saat offline dan akan dikirim saat koneksi kembali.',
                            style: Ui.body(
                              size: 13,
                              color: AppTheme.textDarkPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(transactionsProvider.notifier)
                              .syncOffline(),
                          child: const Text('Kirim'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListRow(
                    leading: const IconBadge(
                      Icons.logout_rounded,
                      color: AppTheme.danger,
                    ),
                    title: 'Keluar',
                    onTap: () async {
                      final ok = await showAppConfirm(
                        context: context,
                        title: 'Keluar dari akun?',
                        message:
                            'Data tetap tersimpan di akunmu dan muncul lagi saat masuk.',
                        confirmLabel: 'Keluar',
                        destructive: true,
                      );
                      if (ok) await ref.read(authProvider.notifier).signOut();
                    },
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

class _Count extends StatelessWidget {
  final int n;
  const _Count(this.n);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$n',
      style: Ui.body(size: 12, color: Colors.white, weight: FontWeight.w600),
    ),
  );
}
