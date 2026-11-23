// lib/features/capture/presentation/capture_link_page.dart
//
// Tujuan deep link dari iOS Shortcuts / Tasker / MacroDroid:
//   pocketflow://app/capture?amount=25000&merchant=Kopi&type=expense&wallet=gopay&date=2026-11-23
// Data masuk ke Perlu Ditinjau, lalu pengguna diarahkan ke sana.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/amount_parser.dart';
import '../../../core/utils/hash.dart';
import '../../transactions/domain/transaction.dart';
import '../../wallets/domain/payment_providers.dart';
import '../domain/capture_models.dart';
import 'providers/capture_provider.dart';

/// Ubah query deep link menjadi kandidat transaksi. Null bila tidak valid.
ParsedCapture? parseCaptureLink(Map<String, String> q, {DateTime? now}) {
  final rawAmount = q['amount'] ?? q['nominal'] ?? '';
  final amount =
      parseNumberToken(rawAmount) ??
      (findAmounts(rawAmount).firstOrNull?.value);
  if (amount == null || amount <= 0 || amount > 10000000000) return null;
  final t = (q['type'] ?? 'expense').toLowerCase();
  final type = t.startsWith('in') || t == 'masuk'
      ? TransactionType.income
      : (t.startsWith('trans')
            ? TransactionType.transfer
            : TransactionType.expense);
  final merchant = q['merchant']?.trim();
  final walletText = q['wallet'] ?? q['card'] ?? '';
  final provider =
      PaymentProviders.byKey(walletText.toLowerCase()) ??
      PaymentProviders.byText(walletText);
  final at = DateTime.tryParse(q['date'] ?? '') ?? (now ?? DateTime.now());
  return ParsedCapture(
    type: type,
    amount: amount,
    merchant: merchant == null || merchant.isEmpty
        ? null
        : merchant.substring(0, merchant.length.clamp(0, 80)),
    providerKey: provider?.key,
    occurredAt: at,
    confidence: 0.7,
    dedupeHash: stableHash(
      'link|$amount|${type.name}|${at.millisecondsSinceEpoch ~/ 60000}|$merchant',
    ),
    source: 'shortcut',
    sourceApp: 'Shortcut',
  );
}

class CaptureLinkPage extends ConsumerStatefulWidget {
  final Map<String, String> query;
  const CaptureLinkPage({super.key, required this.query});

  @override
  ConsumerState<CaptureLinkPage> createState() => _CaptureLinkPageState();
}

class _CaptureLinkPageState extends ConsumerState<CaptureLinkPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final item = parseCaptureLink(widget.query);
    if (item != null) {
      try {
        await ref.read(pendingCapturesProvider.notifier).ingest([item]);
      } catch (_) {}
    }
    if (!mounted) return;
    context.go('/inbox');
    if (item == null) {
      AppTheme.showErrorSnackBar(
        context,
        'Link shortcut tidak berisi nominal yang valid.',
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
