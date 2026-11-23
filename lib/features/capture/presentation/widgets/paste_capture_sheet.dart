// lib/features/capture/presentation/widgets/paste_capture_sheet.dart
//
// Tempel teks notifikasi / SMS bank / bukti transfer. Berguna di iOS (tidak
// bisa membaca notifikasi aplikasi lain) dan untuk menguji parser.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/hash.dart';
import '../../../../core/widgets/app_modal.dart';
import '../../../../core/widgets/ui.dart';
import '../../../smart/domain/quick_text_parser.dart';
import '../../domain/capture_models.dart';
import '../../domain/notification_parser.dart';
import '../providers/capture_provider.dart';

Future<void> showPasteCaptureSheet(BuildContext context) {
  return showAppModal<void>(
    context: context,
    builder: (_) => const PasteCaptureSheet(),
  );
}

class PasteCaptureSheet extends ConsumerStatefulWidget {
  const PasteCaptureSheet({super.key});

  @override
  ConsumerState<PasteCaptureSheet> createState() => _PasteCaptureSheetState();
}

class _PasteCaptureSheetState extends ConsumerState<PasteCaptureSheet> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) setState(() => _ctrl.text = data!.text!);
  }

  /// Ubah teks menjadi kandidat transaksi. Satu baris kosong memisahkan
  /// beberapa notifikasi.
  static List<ParsedCapture> parseText(String text, {DateTime? now}) {
    final at = now ?? DateTime.now();
    const parser = NotificationParser();
    final blocks = text
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty);
    final out = <ParsedCapture>[];
    for (final block in blocks) {
      final lines = block.split('\n');
      final r = parser.parse(
        CapturedNotification(
          packageName: 'paste',
          appName: lines.first,
          title: lines.first,
          text: lines.skip(1).join('\n'),
          postedAt: at,
        ),
        source: 'paste',
      );
      if (r != null) {
        out.add(r);
        continue;
      }
      // Bukan format notifikasi: coba sebagai catatan ketikan biasa.
      for (final d in QuickTextParser(now: at).parse(block)) {
        out.add(
          ParsedCapture(
            type: d.type,
            amount: d.amount,
            merchant: d.merchant,
            providerKey: d.providerKey,
            counterpartyProviderKey: d.toProviderKey,
            occurredAt: d.date,
            confidence: 0.5,
            dedupeHash: stableHash(
              'paste|${d.amount}|${d.type.name}|${d.date}|${d.merchant}',
            ),
            source: 'paste',
          ),
        );
      }
    }
    return out;
  }

  Future<void> _submit() async {
    final items = parseText(_ctrl.text);
    if (items.isEmpty) {
      setState(() => _error = 'Tidak menemukan nominal transaksi di teks ini.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await ref.read(pendingCapturesProvider.notifier).ingest(items);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppTheme.showSuccessSnackBar(
        context,
        n == 0
            ? 'Transaksi ini sudah ada di daftar.'
            : '$n transaksi masuk ke Perlu Ditinjau.',
      );
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModalScaffold(
      title: 'Tempel teks transaksi',
      subtitle:
          'Salin teks notifikasi, SMS bank, atau bukti transfer, lalu tempel di sini.',
      actions: [
        AppModalScaffold.cancelButton(context),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Baca transaksi'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText:
                  'Contoh:\nDANA\nPembayaran QRIS Rp18.500 di Warung Bu Tini berhasil',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_go_rounded, size: 18),
              label: const Text('Tempel dari clipboard'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: Ui.body(size: 13, color: AppTheme.danger)),
          ],
          const SizedBox(height: 8),
          Text(
            'Pisahkan beberapa notifikasi dengan satu baris kosong.',
            style: Ui.body(size: 12.5),
          ),
        ],
      ),
    );
  }
}
