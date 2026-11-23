// lib/features/wallets/domain/payment_providers.dart
//
// Daftar penyedia pembayaran yang dikenali PocketFlow: e-wallet, bank, dan
// aplikasi SMS. Dipakai untuk (1) preset saat membuat dompet dan
// (2) mencocokkan notifikasi dari aplikasi lain ke dompet pengguna.
//
// Nama paket Android harus sama dengan daftar di
// android/app/src/main/kotlin/.../capture/CaptureSources.kt
import 'wallet.dart';

class PaymentProvider {
  final String key;
  final String name;
  final WalletKind kind;
  final List<String> androidPackages;

  /// Kata kunci untuk mengenali penyedia dari judul notifikasi / pengirim SMS.
  final List<String> aliases;
  final int color;

  const PaymentProvider({
    required this.key,
    required this.name,
    required this.kind,
    this.androidPackages = const [],
    this.aliases = const [],
    required this.color,
  });
}

class PaymentProviders {
  static const all = <PaymentProvider>[
    // E-wallet
    PaymentProvider(
      key: 'gopay',
      name: 'GoPay',
      kind: WalletKind.ewallet,
      androidPackages: ['com.gojek.gopay', 'com.gojek.app'],
      aliases: ['gopay', 'gojek'],
      color: 0xFF00AA13,
    ),
    PaymentProvider(
      key: 'ovo',
      name: 'OVO',
      kind: WalletKind.ewallet,
      androidPackages: ['ovo.id'],
      aliases: ['ovo'],
      color: 0xFF4C3494,
    ),
    PaymentProvider(
      key: 'dana',
      name: 'DANA',
      kind: WalletKind.ewallet,
      androidPackages: ['id.dana'],
      aliases: ['dana'],
      color: 0xFF118EEA,
    ),
    PaymentProvider(
      key: 'shopeepay',
      name: 'ShopeePay',
      kind: WalletKind.ewallet,
      androidPackages: ['com.shopee.id'],
      aliases: ['shopeepay', 'shopee'],
      color: 0xFFEE4D2D,
    ),
    PaymentProvider(
      key: 'linkaja',
      name: 'LinkAja',
      kind: WalletKind.ewallet,
      androidPackages: ['com.telkom.mwallet'],
      aliases: ['linkaja'],
      color: 0xFFE82529,
    ),
    PaymentProvider(
      key: 'grab',
      name: 'GrabPay / OVO di Grab',
      kind: WalletKind.ewallet,
      androidPackages: ['com.grabtaxi.passenger'],
      aliases: ['grab'],
      color: 0xFF00B14F,
    ),
    PaymentProvider(
      key: 'flip',
      name: 'Flip',
      kind: WalletKind.ewallet,
      androidPackages: ['id.flip'],
      aliases: ['flip'],
      color: 0xFFFD6542,
    ),
    // Bank
    PaymentProvider(
      key: 'bca',
      name: 'BCA',
      kind: WalletKind.bank,
      androidPackages: ['com.bca', 'com.bca.mybca.omni.android'],
      aliases: ['bca', 'mybca', 'm-bca', 'klikbca'],
      color: 0xFF0060AF,
    ),
    PaymentProvider(
      key: 'blu',
      name: 'blu by BCA Digital',
      kind: WalletKind.bank,
      androidPackages: ['com.bcadigital.blu'],
      aliases: ['blu'],
      color: 0xFF00AEEF,
    ),
    PaymentProvider(
      key: 'bri',
      name: 'BRI',
      kind: WalletKind.bank,
      androidPackages: ['id.co.bri.brimo'],
      aliases: ['bri', 'brimo'],
      color: 0xFF00529C,
    ),
    PaymentProvider(
      key: 'mandiri',
      name: 'Mandiri',
      kind: WalletKind.bank,
      androidPackages: ['id.bmri.livin'],
      aliases: ['mandiri', 'livin'],
      color: 0xFF003D79,
    ),
    PaymentProvider(
      key: 'bni',
      name: 'BNI',
      kind: WalletKind.bank,
      androidPackages: ['src.com.bni', 'id.bni.wondr'],
      aliases: ['bni', 'wondr'],
      color: 0xFFF15A23,
    ),
    PaymentProvider(
      key: 'bsi',
      name: 'BSI',
      kind: WalletKind.bank,
      androidPackages: ['com.bsm.activity2'],
      aliases: ['bsi'],
      color: 0xFF00A39D,
    ),
    PaymentProvider(
      key: 'jago',
      name: 'Bank Jago',
      kind: WalletKind.bank,
      androidPackages: ['com.jago.digitalBanking'],
      aliases: ['jago'],
      color: 0xFFFDB813,
    ),
    PaymentProvider(
      key: 'seabank',
      name: 'SeaBank',
      kind: WalletKind.bank,
      androidPackages: ['id.co.bankbkemobile.digitalbank'],
      aliases: ['seabank'],
      color: 0xFFFF6600,
    ),
    PaymentProvider(
      key: 'jenius',
      name: 'Jenius',
      kind: WalletKind.bank,
      androidPackages: ['com.btpn.dc'],
      aliases: ['jenius'],
      color: 0xFF00A9E0,
    ),
    PaymentProvider(
      key: 'cimb',
      name: 'CIMB Niaga (OCTO)',
      kind: WalletKind.bank,
      androidPackages: ['id.co.cimbniaga.mobile.android'],
      aliases: ['cimb', 'octo'],
      color: 0xFF7A0019,
    ),
    // Paylater / marketplace
    PaymentProvider(
      key: 'spaylater',
      name: 'SPayLater',
      kind: WalletKind.paylater,
      aliases: ['spaylater'],
      color: 0xFFEE4D2D,
    ),
    PaymentProvider(
      key: 'gopaylater',
      name: 'GoPayLater',
      kind: WalletKind.paylater,
      androidPackages: ['com.tokopedia.tkpd'],
      aliases: ['gopaylater', 'paylater'],
      color: 0xFF00AA13,
    ),
    PaymentProvider(
      key: 'kredivo',
      name: 'Kredivo',
      kind: WalletKind.paylater,
      androidPackages: ['com.finaccel.android'],
      aliases: ['kredivo'],
      color: 0xFFFF7A00,
    ),
    // Tunai
    PaymentProvider(
      key: 'cash',
      name: 'Tunai',
      kind: WalletKind.cash,
      aliases: ['tunai', 'cash'],
      color: 0xFF475569,
    ),
  ];

  /// Aplikasi SMS. Notifikasi SMS bank ikut terbaca lewat sini tanpa izin SMS.
  /// Opsional (default mati) karena berisi pesan pribadi.
  static const smsPackages = <String>[
    'com.google.android.apps.messaging',
    'com.samsung.android.messaging',
    'com.android.mms',
    'com.oneplus.mms',
    'com.miui.smsextra',
  ];

  static PaymentProvider? byKey(String? key) {
    if (key == null) return null;
    for (final p in all) {
      if (p.key == key) return p;
    }
    return null;
  }

  static PaymentProvider? byPackage(String? pkg) {
    if (pkg == null) return null;
    for (final p in all) {
      if (p.androidPackages.contains(pkg)) return p;
    }
    return null;
  }

  /// Cari penyedia dari potongan teks (judul notifikasi, nama pengirim SMS).
  static PaymentProvider? byText(String text) {
    final t = text.toLowerCase();
    // Cek alias yang lebih panjang dulu supaya "gopaylater" tidak jadi "gopay".
    final sorted = [...all]..sort((a, b) => _longest(b).compareTo(_longest(a)));
    for (final p in sorted) {
      for (final a in p.aliases) {
        if (RegExp('(^|[^a-z])${RegExp.escape(a)}([^a-z]|\$)').hasMatch(t)) {
          return p;
        }
      }
    }
    return null;
  }

  static int _longest(PaymentProvider p) =>
      p.aliases.fold<int>(0, (m, a) => a.length > m ? a.length : m);

  static List<String> get defaultAndroidPackages => [
    for (final p in all) ...p.androidPackages,
  ];
}
