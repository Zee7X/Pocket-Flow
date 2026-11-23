// lib/features/capture/domain/capture_models.dart
import '../../transactions/domain/transaction.dart';

/// Notifikasi mentah dari aplikasi lain (Android). Hanya hidup di memori
/// perangkat; tidak pernah dikirim ke server.
class CapturedNotification {
  final String packageName;
  final String? appName;
  final String title;
  final String text;
  final DateTime postedAt;

  const CapturedNotification({
    required this.packageName,
    this.appName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  factory CapturedNotification.fromMap(Map<dynamic, dynamic> m) {
    return CapturedNotification(
      packageName: m['package'] as String? ?? '',
      appName: m['app'] as String?,
      title: m['title'] as String? ?? '',
      text: m['text'] as String? ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['postedAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

/// Hasil parsing: kandidat transaksi untuk ditinjau.
class ParsedCapture {
  final TransactionType type;
  final int amount;
  final String? merchant;
  final String? providerKey;

  /// Penyedia lawan transaksi, mis. bank mencatat "Top Up GoPay" -> 'gopay'.
  final String? counterpartyProviderKey;
  final DateTime occurredAt;
  final double confidence;
  final String dedupeHash;

  /// notification | ocr | shortcut | paste
  final String source;
  final String? sourceApp;
  final bool isTopUp;

  const ParsedCapture({
    required this.type,
    required this.amount,
    this.merchant,
    this.providerKey,
    this.counterpartyProviderKey,
    required this.occurredAt,
    required this.confidence,
    required this.dedupeHash,
    required this.source,
    this.sourceApp,
    this.isTopUp = false,
  });

  ParsedCapture copyWith({
    TransactionType? type,
    String? counterpartyProviderKey,
    String? merchant,
  }) => ParsedCapture(
    type: type ?? this.type,
    amount: amount,
    merchant: merchant ?? this.merchant,
    providerKey: providerKey,
    counterpartyProviderKey:
        counterpartyProviderKey ?? this.counterpartyProviderKey,
    occurredAt: occurredAt,
    confidence: confidence,
    dedupeHash: dedupeHash,
    source: source,
    sourceApp: sourceApp,
    isTopUp: isTopUp,
  );

  @override
  String toString() =>
      'ParsedCapture(${type.name}, $amount, merchant: $merchant, provider: $providerKey, counterparty: $counterpartyProviderKey)';
}
