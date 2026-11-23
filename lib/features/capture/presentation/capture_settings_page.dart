// lib/features/capture/presentation/capture_settings_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/responsive_center.dart';
import '../../../core/widgets/ui.dart';
import '../../wallets/domain/payment_providers.dart';
import 'providers/capture_provider.dart';
import 'widgets/paste_capture_sheet.dart';

class CaptureSettingsPage extends ConsumerStatefulWidget {
  const CaptureSettingsPage({super.key});

  @override
  ConsumerState<CaptureSettingsPage> createState() =>
      _CaptureSettingsPageState();
}

class _CaptureSettingsPageState extends ConsumerState<CaptureSettingsPage>
    with WidgetsBindingObserver {
  bool _batteryOk = true;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari halaman Settings Android: perbarui status izin.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(capturePermissionProvider);
      _refreshBattery();
    }
  }

  Future<void> _refreshBattery() async {
    final ok = await ref
        .read(captureChannelProvider)
        .isIgnoringBatteryOptimizations();
    if (mounted) setState(() => _batteryOk = ok);
  }

  Future<void> _enable() async {
    // Prominent disclosure (wajib untuk Google Play) sebelum membuka izin.
    final ok = await showAppConfirm(
      context: context,
      title: 'Izinkan PocketFlow membaca notifikasi?',
      message:
          'PocketFlow akan membaca notifikasi dari aplikasi pembayaran yang kamu pilih (GoPay, OVO, DANA, bank, dan lainnya) '
          'untuk mencatat nominal, arah transaksi, dan nama merchant.\n\n'
          'Teks notifikasi diproses di HP ini saja dan tidak dikirim ke server. Yang disimpan hanya hasilnya: '
          'nominal, merchant, waktu, dan aplikasi asal. Notifikasi dari aplikasi lain diabaikan.\n\n'
          'Kamu bisa mematikan izin ini kapan saja di Pengaturan.',
      confirmLabel: 'Lanjut ke Pengaturan',
    );
    if (!ok) return;
    // Notifikasi "transaksi terdeteksi" butuh izin notifikasi (Android 13+).
    await NotificationService().ensurePermission();
    final channel = ref.read(captureChannelProvider);
    await channel.setAllowedPackages(
      ref.read(captureSettingsProvider).allowedPackages,
    );
    await channel.openPermissionSettings();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(captureSettingsProvider);
    final granted = ref.watch(capturePermissionProvider).value ?? false;

    return Scaffold(
      backgroundColor: AppTheme.canvasLight,
      appBar: plainAppBar(context, 'Deteksi Transaksi Otomatis'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          ResponsiveCenter(
            maxWidth: 720,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isAndroid) ..._androidSection(granted, settings),
                if (_isIos || kIsWeb) ..._iosSection(),
                if (_isAndroid) ...[
                  const SizedBox(height: 24),
                  ..._iosSection(collapsedTitle: 'Punya iPhone juga?'),
                ],
                const SizedBox(height: 24),
                const SectionHeader('Uji pembacaan'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tempel teks notifikasi atau SMS bank untuk melihat bagaimana PocketFlow membacanya. '
                        'Hasilnya masuk ke Perlu Ditinjau.',
                        style: Ui.body(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => showPasteCaptureSheet(context),
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        label: const Text('Tempel teks notifikasi'),
                      ),
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

  List<Widget> _androidSection(bool granted, CaptureSettings settings) {
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(
                  granted
                      ? Icons.check_rounded
                      : Icons.notifications_off_outlined,
                  color: granted ? const Color(0xFF059669) : AppTheme.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        granted ? 'Deteksi aktif' : 'Deteksi belum aktif',
                        style: Ui.title(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        granted
                            ? 'Transaksi dari aplikasi yang dipilih akan masuk ke Perlu Ditinjau.'
                            : 'Butuh izin Akses Notifikasi dari Android.',
                        style: Ui.body(size: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!granted) ...[
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _enable,
                child: const Text('Aktifkan deteksi'),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (!_batteryOk)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Supaya tidak dimatikan sistem', style: Ui.title()),
              const SizedBox(height: 6),
              Text(
                'Deteksi tidak berjalan terus-menerus dan hampir tidak memakai baterai: Android hanya '
                'memanggil PocketFlow saat ada notifikasi baru. Namun beberapa merek HP (Xiaomi, Oppo, Vivo, '
                'Realme, Huawei) suka menghentikan layanan ini. Matikan optimasi baterai untuk PocketFlow, '
                'dan di Xiaomi/Oppo/Vivo aktifkan juga "Autostart" di pengaturan aplikasi.',
                style: Ui.body(),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(captureChannelProvider).openBatterySettings(),
                child: const Text('Buka pengaturan baterai'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 24),
      const SectionHeader('Pencatatan'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              value: settings.autoConfirm,
              onChanged: (v) => ref
                  .read(captureSettingsProvider.notifier)
                  .update(settings.copyWith(autoConfirm: v)),
              title: Text(
                'Catat otomatis tanpa ditinjau',
                style: Ui.body(
                  size: 14,
                  color: AppTheme.textDarkPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Hanya untuk merchant yang kategorinya sudah pernah kamu tentukan. Yang lain tetap masuk Perlu Ditinjau.',
                style: Ui.body(size: 12.5),
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: settings.readSms,
              onChanged: (v) => ref
                  .read(captureSettingsProvider.notifier)
                  .update(settings.copyWith(readSms: v)),
              title: Text(
                'Baca SMS bank',
                style: Ui.body(
                  size: 14,
                  color: AppTheme.textDarkPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Membaca notifikasi aplikasi SMS. Hanya pesan dari pengirim bank/e-wallet yang dikenali yang diproses.',
                style: Ui.body(size: 12.5),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const SectionHeader('Aplikasi yang dibaca'),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final p in PaymentProviders.all.where(
              (p) => p.androidPackages.isNotEmpty,
            )) ...[
              SwitchListTile(
                dense: true,
                value: !settings.disabledProviders.contains(p.key),
                onChanged: (on) {
                  final set = {...settings.disabledProviders};
                  on ? set.remove(p.key) : set.add(p.key);
                  ref
                      .read(captureSettingsProvider.notifier)
                      .update(settings.copyWith(disabledProviders: set));
                },
                secondary: CircleAvatar(
                  radius: 6,
                  backgroundColor: Color(p.color),
                ),
                title: Text(
                  p.name,
                  style: Ui.body(size: 14, color: AppTheme.textDarkPrimary),
                ),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _iosSection({String? collapsedTitle}) {
    const url =
        'pocketflow://app/capture?amount=25000&merchant=Kopi%20Kenangan&type=expense&wallet=gopay';
    return [
      SectionHeader(collapsedTitle ?? 'iPhone'),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'iOS tidak mengizinkan aplikasi membaca notifikasi aplikasi lain. Di iPhone, ada tiga cara cepat:',
              style: Ui.body(),
            ),
            const SizedBox(height: 12),
            _Step(
              n: 1,
              title: 'Scan struk atau screenshot',
              body:
                  'Tombol + → Scan struk. Foto bukti bayar GoPay/OVO/bank juga bisa dibaca.',
            ),
            _Step(
              n: 2,
              title: 'Tempel teks',
              body:
                  'Salin teks notifikasi, lalu buka Perlu Ditinjau → Tempel teks.',
            ),
            _Step(
              n: 3,
              title: 'Shortcuts',
              body:
                  'Buat Personal Automation di app Shortcuts (mis. pemicu "Transaction" untuk Apple Pay), '
                  'lalu aksi "Open URL" dengan alamat seperti di bawah. Ganti nilainya dengan variabel dari Shortcuts.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                url,
                style: Ui.body(size: 12, color: AppTheme.textDarkPrimary),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: url));
                  if (mounted) {
                    AppTheme.showSuccessSnackBar(
                      context,
                      'URL contoh disalin.',
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Salin URL contoh'),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final String body;
  const _Step({required this.n, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF3F8),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: Ui.body(
                size: 12,
                color: AppTheme.textDarkPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Ui.body(
                    size: 13.5,
                    color: AppTheme.textDarkPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: Ui.body(size: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
