// lib/features/smart/data/ai_parse_service.dart
//
// Memanggil Edge Function `ai-parse` (Gemini). Bila AI tidak tersedia
// (belum dipasang, offline, kuota habis), otomatis memakai parser lokal
// sehingga fitur tetap jalan tanpa biaya.
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../categories_rules/domain/category.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/quick_text_parser.dart';

class AiParseResult {
  final List<DraftTransaction> drafts;

  /// True bila hasil berasal dari AI; false = parser lokal.
  final bool usedAi;

  /// Alasan AI tidak dipakai (untuk ditampilkan halus di UI).
  final String? fallbackReason;

  const AiParseResult(this.drafts, {required this.usedAi, this.fallbackReason});
}

class AiParseService {
  final SupabaseClient _client;
  AiParseService(this._client);

  Future<AiParseResult> parseText(
    String text, {
    required List<Category> categories,
    required List<Wallet> wallets,
  }) async {
    try {
      final drafts = await _invoke(
        {'mode': 'text', 'text': text},
        categories,
        wallets,
      );
      if (drafts.isNotEmpty) return AiParseResult(drafts, usedAi: true);
    } catch (e) {
      return AiParseResult(
        QuickTextParser().parse(text),
        usedAi: false,
        fallbackReason: _reason(e),
      );
    }
    return AiParseResult(QuickTextParser().parse(text), usedAi: false);
  }

  Future<AiParseResult> parseReceipt({
    String? ocrText,
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
    required List<Category> categories,
    required List<Wallet> wallets,
  }) async {
    try {
      final drafts = await _invoke(
        {
          if (ocrText != null && ocrText.trim().isNotEmpty) ...{
            'mode': 'receipt_text',
            'text': ocrText,
          } else ...{
            'mode': 'receipt_image',
            'image_base64': base64Encode(imageBytes ?? Uint8List(0)),
            'mime_type': mimeType,
          },
        },
        categories,
        wallets,
      );
      if (drafts.isNotEmpty) return AiParseResult(drafts, usedAi: true);
    } catch (e) {
      final local = ocrText == null ? null : ReceiptTextParser().parse(ocrText);
      return AiParseResult(
        local == null ? const [] : [local],
        usedAi: false,
        fallbackReason: _reason(e),
      );
    }
    final local = ocrText == null ? null : ReceiptTextParser().parse(ocrText);
    return AiParseResult(local == null ? const [] : [local], usedAi: false);
  }

  Future<List<DraftTransaction>> _invoke(
    Map<String, dynamic> body,
    List<Category> categories,
    List<Wallet> wallets,
  ) async {
    final now = DateTime.now();
    final res = await _client.functions.invoke(
      'ai-parse',
      body: {
        ...body,
        'today':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'categories': [
          for (final c in categories)
            {'id': c.id, 'name': c.name, 'type': c.type.toDbString()},
        ],
        'wallets': [
          for (final w in wallets) {'id': w.id, 'name': w.name},
        ],
      },
    );
    final data = res.data;
    final list =
        (data is Map ? data['transactions'] : null) as List? ?? const [];
    return [
      for (final t in list.whereType<Map>())
        DraftTransaction(
          type: TransactionType.fromString(t['type'] as String? ?? 'expense'),
          amount: (t['amount'] as num).toInt(),
          merchant: t['merchant'] as String? ?? t['note'] as String?,
          note: t['note'] as String? ?? t['merchant'] as String?,
          date:
              DateTime.tryParse(t['date'] as String? ?? '') ??
              DateTime(now.year, now.month, now.day),
          categoryId: t['category_id'] as String?,
          walletId: t['wallet_id'] as String?,
          toWalletId: t['to_wallet_id'] as String?,
        ),
    ];
  }

  String _reason(Object e) {
    final s = e.toString();
    if (s.contains('ai_not_configured') ||
        s.contains('404') ||
        s.contains('NOT_FOUND')) {
      return 'AI belum diaktifkan, memakai pembaca lokal.';
    }
    if (s.contains('rate_limited') || s.contains('429')) {
      return 'Kuota AI gratis hari ini habis, memakai pembaca lokal.';
    }
    return 'AI tidak bisa dihubungi, memakai pembaca lokal.';
  }
}
