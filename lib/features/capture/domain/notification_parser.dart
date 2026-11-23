// lib/features/capture/domain/notification_parser.dart
//
// Mengubah teks notifikasi e-wallet / bank / SMS bank menjadi kandidat
// transaksi. Berjalan sepenuhnya di perangkat, tanpa jaringan.
//
// Prinsip: lebih baik melewatkan notifikasi daripada mencatat promo atau OTP
// sebagai transaksi. Hasil parsing selalu masuk "Perlu Ditinjau" dulu.
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/hash.dart';
import '../../smart/domain/category_suggester.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/domain/payment_providers.dart';
import 'capture_models.dart';

class NotificationParser {
  const NotificationParser();

  static final _otp = RegExp(
    r'\b(otp|kode verifikasi|kode rahasia|verification code|jangan (berikan|bagikan)|one[- ]time)\b',
    caseSensitive: false,
  );
  static final _promo = RegExp(
    r'(promo|diskon|voucher|cashback (hingga|s\.?d|sampai|up to)|dapatkan|gratis ongkir|flash ?sale|hemat|berlaku (hingga|sampai)|klaim|undian|kupon|penawaran|spesial|special|limited|ayo|yuk|jangan lewatkan|hanya hari ini|s\.?d\.? \d|up to)',
    caseSensitive: false,
  );
  static final _failed = RegExp(
    r'(gagal|dibatalkan|ditolak|tidak berhasil|failed|declined|pending|menunggu pembayaran|segera bayar|tagihan .*jatuh tempo|belum dibayar)',
    caseSensitive: false,
  );
  static final _success = RegExp(
    r'(berhasil|sukses|telah|sudah|diterima|masuk|menerima|terima|dibayar|dikirim|terdebet|didebet|dikredit|successful|success|received|paid)',
    caseSensitive: false,
  );

  static final _incomeRe = RegExp(
    r'(diterima|menerima|kamu terima|anda terima|dana masuk|uang masuk|transfer masuk|saldo masuk|masuk ke|dikreditkan|dikredit|\bkredit\b|\bcr\b|refund|pengembalian dana|dana dikembalikan|cashback (rp|idr|sebesar|senilai|\d)|received|incoming)',
    caseSensitive: false,
  );
  static final _expenseRe = RegExp(
    r'(pembayaran|bayar|membayar|dibayar|transfer ke|transfer keluar|kirim uang|mengirim|dikirim ke|terkirim|\bdebit\b|didebet|terdebet|\bdb\b|keluar|tarik tunai|penarikan|pembelian|belanja|qris|potong|autodebet|auto[- ]debit|payment|paid|purchase|spent)',
    caseSensitive: false,
  );
  static final _topUp = RegExp(
    r'(top ?up|isi saldo|isi ulang saldo)',
    caseSensitive: false,
  );
  static final _balanceBefore = RegExp(
    r'(saldo|sisa|limit|biaya admin|biaya layanan|fee|poin|point|min(imal|\.)? ?(transaksi|belanja)|maks)\s*[:\-]?\s*(anda|kamu|akhir|tersedia|saat ini|sekarang)?\s*[:\-]?\s*$',
    caseSensitive: false,
  );

  static final _merchantAfter = RegExp(
    r'\b(?:di|ke|kepada|pada merchant|merchant|untuk|at|to)\s+([A-Za-z0-9][A-Za-z0-9&@\x27.\-/ ]{1,40}?)(?=\s+(?:berhasil|sebesar|senilai|sejumlah|telah|sudah|pada|tgl|tanggal|via|dgn|dengan|menggunakan|pakai|rp|idr|ref|no\.?)\b|\s*[.,!;:(]|\s*$)',
    caseSensitive: false,
  );
  static final _merchantFrom = RegExp(
    r'\bdari\s+([A-Za-z0-9][A-Za-z0-9&@\x27.\-/ ]{1,40}?)(?=\s+(?:berhasil|sebesar|senilai|sejumlah|telah|sudah|pada|tgl|tanggal|via|ke|rp|idr|ref|no\.?)\b|\s*[.,!;:(]|\s*$)',
    caseSensitive: false,
  );

  ParsedCapture? parse(
    CapturedNotification n, {
    String source = 'notification',
  }) {
    final full = '${n.title}\n${n.text}'.trim();
    if (full.isEmpty) return null;
    if (_otp.hasMatch(full)) return null;
    if (_failed.hasMatch(full)) return null;

    final hasSuccess = _success.hasMatch(full);
    if (_promo.hasMatch(full) && !hasSuccess) return null;

    final amount = _pickAmount(full);
    if (amount == null) return null;

    final isIncome = _incomeRe.hasMatch(full);
    final isExpense = _expenseRe.hasMatch(full);
    final isTopUp = _topUp.hasMatch(full);

    final provider =
        PaymentProviders.byPackage(n.packageName) ??
        PaymentProviders.byText('${n.appName ?? ''} ${n.title}');
    final fromSms = PaymentProviders.smsPackages.contains(n.packageName);
    // SMS tanpa penyedia keuangan yang dikenali hampir pasti bukan notifikasi
    // transaksi (mis. pesan teman yang menyebut "Rp").
    if (fromSms && provider == null) return null;

    TransactionType type;
    if (isTopUp) {
      // E-wallet: "Top up Rp50.000 berhasil" = saldo masuk.
      // Bank: "Top Up GoPay Rp50.000" = uang keluar.
      type =
          provider?.kind.name == 'ewallet' && !_mentionsOther(full, provider!)
          ? TransactionType.income
          : TransactionType.expense;
    } else if (isIncome && !isExpense) {
      type = TransactionType.income;
    } else if (isExpense && !isIncome) {
      type = TransactionType.expense;
    } else if (isIncome && isExpense) {
      // "Transfer masuk dari X" vs "Transfer ke X": cari frasa terkuat.
      type =
          RegExp(
                r'(masuk|diterima|menerima|dari)',
                caseSensitive: false,
              ).hasMatch(full) &&
              !RegExp(r'\b(ke|kepada)\b', caseSensitive: false).hasMatch(full)
          ? TransactionType.income
          : TransactionType.expense;
    } else {
      // Tidak ada kata arah transaksi sama sekali: lewati.
      return null;
    }

    var merchant = _extractMerchant(full, type);
    PaymentProvider? counterparty;
    if (isTopUp && provider != null) {
      counterparty = _findOtherProvider(full, provider);
      if (type == TransactionType.expense && counterparty != null) {
        merchant ??= 'Top up ${counterparty.name}';
      }
    }

    var confidence = 0.4;
    if (hasSuccess) confidence += 0.2;
    if (merchant != null) confidence += 0.15;
    if (provider != null) confidence += 0.15;
    if (isIncome != isExpense) confidence += 0.1;

    final bucket = n.postedAt.millisecondsSinceEpoch ~/ 120000;
    final hash = stableHash(
      '${n.packageName}|$amount|${type.name}|$bucket|${merchantKey(merchant ?? '')}',
    );

    return ParsedCapture(
      type: type,
      amount: amount,
      merchant: merchant,
      providerKey: provider?.key,
      counterpartyProviderKey: counterparty?.key,
      occurredAt: n.postedAt,
      confidence: confidence.clamp(0, 1).toDouble(),
      dedupeHash: hash,
      source: source,
      sourceApp: provider?.name ?? n.appName,
      isTopUp: isTopUp,
    );
  }

  int? _pickAmount(String text) {
    final matches = findAmounts(text);
    for (final m in matches) {
      final before = text.substring((m.start - 28).clamp(0, m.start), m.start);
      if (_balanceBefore.hasMatch(before)) continue;
      return m.value;
    }
    return null;
  }

  bool _mentionsOther(String text, PaymentProvider self) =>
      _findOtherProvider(text, self) != null &&
      RegExp(r'\b(ke|to)\b', caseSensitive: false).hasMatch(text);

  PaymentProvider? _findOtherProvider(String text, PaymentProvider self) {
    final t = text.toLowerCase();
    for (final p in PaymentProviders.all) {
      if (p.key == self.key) continue;
      for (final a in p.aliases) {
        if (a.length < 3) continue;
        if (RegExp('(^|[^a-z])${RegExp.escape(a)}([^a-z]|\$)').hasMatch(t)) {
          return p;
        }
      }
    }
    return null;
  }

  String? _extractMerchant(String text, TransactionType type) {
    final re = type == TransactionType.income ? _merchantFrom : _merchantAfter;
    for (final m in re.allMatches(text)) {
      final cleaned = _cleanMerchant(m.group(1)!);
      if (cleaned != null) return cleaned;
    }
    if (type == TransactionType.income) return null;
    // Cadangan: "Pembayaran QRIS Kopi Kenangan Rp..." -> kata setelah "pembayaran".
    final alt = RegExp(
      r'(?:pembayaran|bayar|belanja|pembelian)\s+(?:qris\s+|di\s+)?([A-Za-z][A-Za-z0-9&\x27.\- ]{2,40}?)\s+(?:rp|idr|sebesar|senilai|berhasil)',
      caseSensitive: false,
    ).firstMatch(text);
    return alt == null ? null : _cleanMerchant(alt.group(1)!);
  }

  static const _notMerchant = {
    'anda',
    'kamu',
    'rekening',
    'rekening anda',
    'saldo',
    'akun',
    'akun anda',
    'aplikasi',
    'sini',
    'sana',
    'nomor',
    'no',
    'hari ini',
    'kami',
    'merchant',
  };

  String? _cleanMerchant(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    s = s.replaceAll(RegExp(r'^(merchant|toko)\s+', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'[\s\-.]+$'), '');
    if (s.length < 2) return null;
    if (_notMerchant.contains(s.toLowerCase())) return null;
    if (RegExp(r'^\d+$').hasMatch(s)) return null;
    if (RegExp(r'^(rp|idr)\b', caseSensitive: false).hasMatch(s)) return null;
    return s;
  }
}
