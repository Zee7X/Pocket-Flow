// lib/features/smart/domain/category_suggester.dart
//
// Kategori otomatis:
// 1. Aturan merchant milik pengguna (dipelajari dari koreksi) menang lebih dulu.
// 2. Bila belum ada, cocokkan kata kunci merchant/catatan ke kelompok umum
//    (makan, transport, belanja, ...) lalu cari kategori pengguna yang
//    namanya paling mirip kelompok itu.
import '../../categories_rules/domain/category.dart';

/// Normalisasi nama merchant menjadi kunci stabil.
/// "KOPI KENANGAN - Sudirman 12" -> "kopi kenangan sudirman"
String merchantKey(String raw) {
  var s = raw.toLowerCase();
  s = s.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  const drop = {
    'pt',
    'cv',
    'tbk',
    'id',
    'indonesia',
    'official',
    'store',
    'shop',
    'cab',
    'cabang',
  };
  final tokens = s
      .split(RegExp(r'\s+'))
      .where(
        (t) =>
            t.isNotEmpty && !drop.contains(t) && !RegExp(r'^\d+$').hasMatch(t),
      )
      .take(3)
      .toList();
  return tokens.join(' ');
}

class _Group {
  final List<String> categoryHints;
  final List<String> keywords;
  const _Group(this.categoryHints, this.keywords);
}

const _groups = <String, _Group>{
  'makan': _Group(
    ['makan', 'food', 'kuliner', 'jajan', 'minum', 'kopi', 'konsumsi'],
    [
      'gofood',
      'grabfood',
      'shopeefood',
      'kopi',
      'coffee',
      'cafe',
      'resto',
      'restoran',
      'warung',
      'warteg',
      'bakso',
      'mie ',
      'mie',
      'ayam',
      'pizza',
      'kfc',
      'mcd',
      'mcdonald',
      'starbucks',
      'janji jiwa',
      'chatime',
      'hokben',
      'solaria',
      'kenangan',
      'martabak',
      'sate',
      'nasi',
      'makan',
      'burger',
      'roti',
      'bakery',
      'geprek',
      'padang',
      'seblak',
      'boba',
      'mixue',
      'richeese',
      'dimsum',
      'sushi',
      'ramen',
    ],
  ),
  'transport': _Group(
    ['transport', 'bensin', 'kendaraan', 'ojek', 'perjalanan'],
    [
      'goride',
      'gocar',
      'grabbike',
      'grabcar',
      'grab bike',
      'grab car',
      'maxim',
      'indrive',
      'krl',
      'mrt',
      'lrt',
      'transjakarta',
      'commuter',
      'bensin',
      'pertamina',
      'shell',
      'spbu',
      'parkir',
      'tol',
      'e-toll',
      'kai',
      'tiket kereta',
      'bluebird',
      'gojek',
    ],
  ),
  'belanja': _Group(
    ['belanja', 'shopping', 'kebutuhan', 'groceries', 'rumah tangga'],
    [
      'indomaret',
      'alfamart',
      'alfamidi',
      'tokopedia',
      'shopee',
      'lazada',
      'blibli',
      'superindo',
      'hypermart',
      'transmart',
      'lottemart',
      'giant',
      'ikea',
      'ace hardware',
      'informa',
      'uniqlo',
      'h&m',
      'zara',
      'tiktok shop',
      'gomart',
      'grabmart',
      'astro',
    ],
  ),
  'tagihan': _Group(
    ['tagihan', 'listrik', 'internet', 'pulsa', 'utilitas', 'bill'],
    [
      'pln',
      'listrik',
      'token',
      'pdam',
      'indihome',
      'biznet',
      'myrepublic',
      'first media',
      'firstmedia',
      'telkomsel',
      'xl ',
      'axis',
      'indosat',
      'im3',
      'smartfren',
      'tri ',
      'pulsa',
      'paket data',
      'bpjs',
      'iuran',
      'wifi',
    ],
  ),
  'hiburan': _Group(
    ['hiburan', 'langganan', 'entertainment', 'subscription', 'hobi'],
    [
      'netflix',
      'spotify',
      'youtube',
      'disney',
      'vidio',
      'viu',
      'wetv',
      'iqiyi',
      'steam',
      'playstation',
      'xbox',
      'nintendo',
      'bioskop',
      'cgv',
      'xxi',
      'cinepolis',
      'prime video',
      'apple.com',
      'google play',
      'icloud',
      'chatgpt',
      'canva',
    ],
  ),
  'kesehatan': _Group(
    ['kesehatan', 'obat', 'medis', 'health'],
    [
      'apotek',
      'kimia farma',
      'guardian',
      'watsons',
      'century',
      'halodoc',
      'alodokter',
      'klinik',
      'rumah sakit',
      'rs ',
      'dokter',
      'gym',
      'fitness',
    ],
  ),
  'pendidikan': _Group(
    ['pendidikan', 'kursus', 'sekolah', 'kuliah', 'belajar'],
    [
      'ruangguru',
      'zenius',
      'udemy',
      'coursera',
      'gramedia',
      'spp',
      'kursus',
      'les ',
    ],
  ),
  'sedekah': _Group(
    ['sedekah', 'donasi', 'zakat', 'amal', 'infaq'],
    [
      'kitabisa',
      'baznas',
      'dompet dhuafa',
      'zakat',
      'infaq',
      'sedekah',
      'donasi',
    ],
  ),
};

class CategorySuggester {
  /// merchantKey -> categoryId
  final Map<String, String> userRules;
  final List<Category> categories;

  const CategorySuggester({required this.userRules, required this.categories});

  /// Mengembalikan id kategori dan sumber saran ('rule' / 'keyword'), atau null.
  ({String categoryId, String reason})? suggest({
    String? merchant,
    String? note,
    required bool isIncome,
  }) {
    final wanted = isIncome ? CategoryType.income : CategoryType.expense;
    final candidates = categories.where((c) => c.type == wanted).toList();
    if (candidates.isEmpty) return null;

    if (merchant != null && merchant.trim().isNotEmpty) {
      final key = merchantKey(merchant);
      final ruleCat = userRules[key];
      if (ruleCat != null && candidates.any((c) => c.id == ruleCat)) {
        return (categoryId: ruleCat, reason: 'rule');
      }
    }

    if (isIncome) {
      final text = '${merchant ?? ''} ${note ?? ''}'.toLowerCase();
      final List<String> hint;
      if (text.contains('freelance') ||
          text.contains('proyek') ||
          text.contains('klien')) {
        hint = ['freelance', 'lain'];
      } else if (text.contains('bonus') || text.contains('thr')) {
        hint = ['bonus', 'thr', 'lain'];
      } else if (text.contains('gaji') || text.contains('payroll')) {
        hint = ['gaji'];
      } else if (text.contains('refund') || text.contains('cashback')) {
        hint = ['lain', 'refund', 'cashback'];
      } else {
        hint = ['lain', 'freelance'];
      }
      final c = _matchByName(candidates, hint);
      return c == null ? null : (categoryId: c.id, reason: 'keyword');
    }

    final text = ' ${merchant ?? ''} ${note ?? ''} '.toLowerCase();
    for (final g in _groups.values) {
      if (g.keywords.any(text.contains)) {
        final c = _matchByName(candidates, g.categoryHints);
        if (c != null) return (categoryId: c.id, reason: 'keyword');
      }
    }
    return null;
  }

  static Category? _matchByName(List<Category> cats, List<String> hints) {
    for (final h in hints) {
      for (final c in cats) {
        if (c.name.toLowerCase().contains(h)) return c;
      }
    }
    return null;
  }
}
