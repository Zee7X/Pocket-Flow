import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/core/utils/amount_parser.dart';
import 'package:pocket_flow/features/capture/domain/capture_models.dart';
import 'package:pocket_flow/features/capture/domain/notification_parser.dart';
import 'package:pocket_flow/features/capture/domain/transfer_matcher.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';

CapturedNotification n(String pkg, String title, String text, {DateTime? at}) =>
    CapturedNotification(
      packageName: pkg,
      title: title,
      text: text,
      postedAt: at ?? DateTime(2026, 11, 23, 12, 30),
    );

void main() {
  const parser = NotificationParser();

  group('amount parser', () {
    test('format Indonesia dan Inggris', () {
      expect(parseNumberToken('25.000'), 25000);
      expect(parseNumberToken('1.250.000,00'), 1250000);
      expect(parseNumberToken('25,000.00'), 25000);
      expect(parseNumberToken('150000'), 150000);
      expect(parseNumberToken('1,250,000'), 1250000);
    });

    test('satuan rb / jt / k', () {
      expect(parseAmountWithUnit('25', 'rb'), 25000);
      expect(parseAmountWithUnit('1,5', 'jt'), 1500000);
      expect(parseAmountWithUnit('2.5', 'juta'), 2500000);
      expect(parseAmountWithUnit('50', 'k'), 50000);
    });

    test('findAmounts mengabaikan angka tanpa penanda', () {
      final m = findAmounts('Order 12345 Rp 18.500 berhasil, poin 200');
      expect(m.map((e) => e.value), [18500]);
      expect(findAmounts('makan bakso 25rb').single.value, 25000);
    });
  });

  group('NotificationParser', () {
    test('pembayaran GoPay ke merchant', () {
      final r = parser.parse(n('com.gojek.app', 'Pembayaran berhasil',
          'Kamu bayar Rp25.000 ke Kopi Kenangan pakai GoPay.'))!;
      expect(r.type, TransactionType.expense);
      expect(r.amount, 25000);
      expect(r.merchant, 'Kopi Kenangan');
      expect(r.providerKey, 'gopay');
    });

    test('OVO menerima uang', () {
      final r = parser.parse(n('ovo.id', 'Dana Masuk',
          'Kamu menerima Rp150.000 dari Budi Santoso.'))!;
      expect(r.type, TransactionType.income);
      expect(r.amount, 150000);
      expect(r.merchant, 'Budi Santoso');
      expect(r.providerKey, 'ovo');
    });

    test('transfer BCA mengabaikan saldo akhir', () {
      final r = parser.parse(n('com.bca', 'm-BCA',
          'Transfer ke ANDI WIJAYA sebesar Rp 1.250.000,00 berhasil. Saldo Rp 3.400.000,00'))!;
      expect(r.type, TransactionType.expense);
      expect(r.amount, 1250000);
      expect(r.merchant, 'ANDI WIJAYA');
    });

    test('QRIS DANA', () {
      final r = parser.parse(n('id.dana', 'DANA',
          'Pembayaran QRIS Rp18.500 di Warung Bu Tini berhasil'))!;
      expect(r.type, TransactionType.expense);
      expect(r.amount, 18500);
      expect(r.merchant, 'Warung Bu Tini');
    });

    test('promo dan OTP diabaikan', () {
      expect(parser.parse(n('com.gojek.app', 'Promo hari ini',
          'Dapatkan cashback hingga Rp50.000 pakai GoPay!')), isNull);
      expect(parser.parse(n('com.bca', 'BCA',
          'Kode OTP 123456 untuk transaksi Rp100.000. Jangan berikan ke siapa pun.')), isNull);
    });

    test('transaksi gagal diabaikan', () {
      expect(parser.parse(n('id.dana', 'DANA',
          'Pembayaran Rp45.000 ke Tokopedia gagal.')), isNull);
    });

    test('SMS pribadi tanpa penyedia diabaikan', () {
      expect(parser.parse(n('com.google.android.apps.messaging', 'Rina',
          'transfer ke aku Rp50.000 ya')), isNull);
    });

    test('SMS bank terbaca lewat aplikasi Messages', () {
      final r = parser.parse(n('com.google.android.apps.messaging', 'BRI',
          'BRI: Transaksi debit Rp 75.000 di INDOMARET berhasil. Saldo Rp 1.200.000'))!;
      expect(r.type, TransactionType.expense);
      expect(r.amount, 75000);
      expect(r.providerKey, 'bri');
    });

    test('top up dari bank ke GoPay digabung jadi transfer', () {
      final t = DateTime(2026, 11, 23, 9, 0);
      final out = parser.parse(n('com.bca', 'BCA', 'Top Up GoPay Rp100.000 berhasil', at: t))!;
      final inc = parser.parse(n('com.gojek.app', 'GoPay',
          'Top up Rp100.000 berhasil. Saldo GoPay kamu sekarang Rp230.000',
          at: t.add(const Duration(seconds: 40))))!;
      expect(out.type, TransactionType.expense);
      expect(out.counterpartyProviderKey, 'gopay');
      expect(inc.type, TransactionType.income);

      final merged = const TransferMatcher().merge([out, inc]);
      expect(merged.length, 1);
      expect(merged.single.type, TransactionType.transfer);
      expect(merged.single.providerKey, 'bca');
      expect(merged.single.counterpartyProviderKey, 'gopay');
    });

    test('hash dedupe sama untuk notifikasi yang diperbarui', () {
      final a = parser.parse(n('com.gojek.app', 'Pembayaran berhasil',
          'Kamu bayar Rp25.000 ke Kopi Kenangan pakai GoPay.'))!;
      final b = parser.parse(n('com.gojek.app', 'Pembayaran berhasil',
          'Kamu bayar Rp25.000 ke Kopi Kenangan pakai GoPay.',
          at: DateTime(2026, 11, 23, 12, 30, 20)))!;
      expect(a.dedupeHash, b.dedupeHash);
    });
  });
}
