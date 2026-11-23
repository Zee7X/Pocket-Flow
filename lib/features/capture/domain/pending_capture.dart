// lib/features/capture/domain/pending_capture.dart
import '../../transactions/domain/transaction.dart';

/// Baris pf_pending_transactions: transaksi terdeteksi yang menunggu ditinjau.
class PendingCapture {
  final String id;
  final String source;
  final String? sourceApp;
  final String? providerKey;
  final TransactionType type;
  final int amount;
  final String? merchant;
  final DateTime occurredAt;
  final String? suggestedCategoryId;
  final String? suggestedWalletId;
  final String? toWalletId;
  final double confidence;
  final String dedupeHash;
  final String status;

  const PendingCapture({
    required this.id,
    required this.source,
    this.sourceApp,
    this.providerKey,
    required this.type,
    required this.amount,
    this.merchant,
    required this.occurredAt,
    this.suggestedCategoryId,
    this.suggestedWalletId,
    this.toWalletId,
    this.confidence = 0.5,
    required this.dedupeHash,
    this.status = 'pending',
  });

  String get sourceLabel => switch (source) {
    'notification' => 'Notifikasi',
    'ocr' => 'Scan struk',
    'shortcut' => 'Shortcut',
    'paste' => 'Teks ditempel',
    'ai' => 'Catat pintar',
    _ => source,
  };

  factory PendingCapture.fromJson(Map<String, dynamic> j) => PendingCapture(
    id: j['id'] as String,
    source: j['source'] as String,
    sourceApp: j['source_app'] as String?,
    providerKey: j['provider_key'] as String?,
    type: TransactionType.fromString(j['type'] as String),
    amount: (j['amount'] as num).toInt(),
    merchant: j['merchant'] as String?,
    occurredAt: DateTime.parse(j['occurred_at'] as String).toLocal(),
    suggestedCategoryId: j['suggested_category_id'] as String?,
    suggestedWalletId: j['suggested_wallet_id'] as String?,
    toWalletId: j['to_wallet_id'] as String?,
    confidence: (j['confidence'] as num?)?.toDouble() ?? 0.5,
    dedupeHash: j['dedupe_hash'] as String,
    status: j['status'] as String? ?? 'pending',
  );
}
