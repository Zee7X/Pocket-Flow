// lib/features/splits/domain/split_bill.dart
class SplitParticipant {
  final String id;
  final String name;
  final int shareAmount;
  final bool isSettled;
  final DateTime? settledAt;

  const SplitParticipant({
    required this.id,
    required this.name,
    required this.shareAmount,
    this.isSettled = false,
    this.settledAt,
  });

  factory SplitParticipant.fromJson(Map<String, dynamic> j) => SplitParticipant(
    id: j['id'] as String,
    name: j['name'] as String,
    shareAmount: (j['share_amount'] as num).toInt(),
    isSettled: j['is_settled'] as bool? ?? false,
    settledAt: j['settled_at'] == null
        ? null
        : DateTime.parse(j['settled_at'] as String),
  );
}

class SplitBill {
  final String id;
  final String title;
  final int totalAmount;
  final int myShare;
  final DateTime splitDate;
  final String? walletId;
  final String? categoryId;
  final List<SplitParticipant> participants;

  const SplitBill({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.myShare,
    required this.splitDate,
    this.walletId,
    this.categoryId,
    this.participants = const [],
  });

  int get outstanding => participants
      .where((p) => !p.isSettled)
      .fold(0, (s, p) => s + p.shareAmount);
  bool get isSettled => outstanding == 0;

  factory SplitBill.fromJson(Map<String, dynamic> j) => SplitBill(
    id: j['id'] as String,
    title: j['title'] as String,
    totalAmount: (j['total_amount'] as num).toInt(),
    myShare: (j['my_share'] as num).toInt(),
    splitDate: DateTime.parse(j['split_date'] as String),
    walletId: j['wallet_id'] as String?,
    categoryId: j['category_id'] as String?,
    participants:
        ((j['pf_split_participants'] as List?) ?? const [])
            .map(
              (p) => SplitParticipant.fromJson(
                Map<String, dynamic>.from(p as Map),
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );
}

/// Bagi rata total ke [count] orang (termasuk saya). Sisa pembulatan
/// ditanggung saya supaya total tetap pas.
List<int> splitEvenly(int total, int count) {
  if (count <= 0) return const [];
  final base = total ~/ count;
  final remainder = total - base * count;
  return [base + remainder, for (var i = 1; i < count; i++) base];
}
