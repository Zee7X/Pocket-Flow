import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_flow/features/categories_rules/domain/category.dart';
import 'package:pocket_flow/features/smart/domain/category_suggester.dart';
import 'package:pocket_flow/features/smart/domain/quick_text_parser.dart';
import 'package:pocket_flow/features/transactions/domain/transaction.dart';

void main() {
  final now = DateTime(2026, 11, 23, 10);

  group('QuickTextParser', () {
    test('pengeluaran sederhana dengan dompet dan tanggal relatif', () {
      final r = QuickTextParser(now: now).parse('makan bakso 25rb pakai gopay kemarin');
      expect(r.length, 1);
      expect(r.first.type, TransactionType.expense);
      expect(r.first.amount, 25000);
      expect(r.first.providerKey, 'gopay');
      expect(r.first.date, DateTime(2026, 11, 22));
      expect(r.first.merchant, 'Makan bakso');
    });

    test('beberapa transaksi dalam satu kalimat', () {
      final r = QuickTextParser(now: now)
          .parse('gaji 8,5jt masuk bca, bayar kos 1.800.000 dan kopi 18rb');
      expect(r.map((e) => e.amount), [8500000, 1800000, 18000]);
      expect(r.first.type, TransactionType.income);
      expect(r.first.providerKey, 'bca');
      expect(r[1].type, TransactionType.expense);
    });

    test('top up antar dompet jadi transfer', () {
      final r = QuickTextParser(now: now).parse('top up gopay 100rb dari bca');
      expect(r.single.type, TransactionType.transfer);
      expect(r.single.providerKey, 'bca');
      expect(r.single.toProviderKey, 'gopay');
    });

    test('angka polos tetap terbaca', () {
      final r = QuickTextParser(now: now).parse('parkir 5000');
      expect(r.single.amount, 5000);
    });
  });

  group('ReceiptTextParser', () {
    test('mengambil grand total, bukan subtotal atau tunai', () {
      const ocr = '''
INDOMARET SUDIRMAN
Jl. Sudirman No 1
23/11/2026 08:12
AQUA 600ML      4.000
ROTI TAWAR     16.500
SUBTOTAL       20.500
PPN             2.255
TOTAL          22.755
TUNAI          50.000
KEMBALI        27.245
''';
      final r = ReceiptTextParser().parse(ocr, now: now)!;
      expect(r.amount, 22755);
      expect(r.merchant, 'Indomaret Sudirman');
      expect(r.date, DateTime(2026, 11, 23));
    });
  });

  group('CategorySuggester', () {
    final cats = [
      Category(id: 'makan', userId: 'u', name: 'Makan & Minum', type: CategoryType.expense, createdAt: now),
      Category(id: 'trans', userId: 'u', name: 'Transportasi', type: CategoryType.expense, createdAt: now),
      Category(id: 'gaji', userId: 'u', name: 'Gaji Utama', type: CategoryType.income, createdAt: now),
    ];

    test('kata kunci merchant', () {
      final s = CategorySuggester(userRules: const {}, categories: cats);
      expect(s.suggest(merchant: 'GoFood - Ayam Geprek', isIncome: false)?.categoryId, 'makan');
      expect(s.suggest(merchant: 'KRL Commuter', isIncome: false)?.categoryId, 'trans');
      expect(s.suggest(merchant: 'Gaji November', isIncome: true)?.categoryId, 'gaji');
    });

    test('aturan pengguna menang atas kata kunci', () {
      final s = CategorySuggester(
        userRules: {merchantKey('Kopi Kenangan'): 'trans'},
        categories: cats,
      );
      final r = s.suggest(merchant: 'KOPI KENANGAN', isIncome: false)!;
      expect(r.categoryId, 'trans');
      expect(r.reason, 'rule');
    });
  });
}
