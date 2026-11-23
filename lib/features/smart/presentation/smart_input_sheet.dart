// lib/features/smart/presentation/smart_input_sheet.dart
//
// "Catat Pintar": ketik bebas, bicara, atau foto struk. AI (Gemini) mengubah
// input menjadi transaksi; bila AI tidak tersedia, parser lokal dipakai.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../app/theme.dart';
import '../../../core/extensions/currency_extension.dart';
import '../../../core/utils/date_id.dart';
import '../../../core/utils/error_helper.dart';
import '../../../core/utils/hash.dart';
import '../../../core/widgets/app_modal.dart';
import '../../../core/widgets/ui.dart';
import '../../categories_rules/presentation/providers/categories_rules_provider.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/providers/transactions_provider.dart';
import '../../wallets/presentation/providers/wallets_provider.dart';
import '../data/receipt_ocr.dart';
import '../domain/quick_text_parser.dart';
import 'providers/smart_input_provider.dart';
import 'widgets/draft_editor_sheet.dart';

enum SmartInputStart { text, voice, receipt }

Future<void> showSmartInputSheet(
  BuildContext context, {
  SmartInputStart start = SmartInputStart.text,
}) {
  return showAppModal<void>(
    context: context,
    builder: (_) => SmartInputSheet(start: start),
  );
}

/// Mode "tinggal ngomong": langsung mendengarkan, lalu menyimpan otomatis
/// bila semua transaksi yang terbaca sudah punya nominal dan kategori.
/// Bila ada yang belum lengkap, hasilnya ditampilkan untuk ditinjau dulu.
/// Setelah tersimpan muncul snackbar dengan tombol Batalkan.
Future<void> showVoiceCapture(BuildContext context) {
  return showAppModal<void>(
    context: context,
    builder: (_) =>
        const SmartInputSheet(start: SmartInputStart.voice, autoSave: true),
  );
}

class SmartInputSheet extends ConsumerStatefulWidget {
  final SmartInputStart start;

  /// Simpan otomatis setelah selesai bicara (lihat [showVoiceCapture]).
  final bool autoSave;
  const SmartInputSheet({
    super.key,
    this.start = SmartInputStart.text,
    this.autoSave = false,
  });

  @override
  ConsumerState<SmartInputSheet> createState() => _SmartInputSheetState();
}

class _SmartInputSheetState extends ConsumerState<SmartInputSheet> {
  final _text = TextEditingController();
  final _speech = SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  bool _busy = false;
  String? _lastAnalyzed;

  /// Info kendala AI (kuota habis, offline, dll.).
  String? _notice;
  String? _info;
  String _source = 'ai';
  List<DraftTransaction> _drafts = const [];
  int? _editing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.start == SmartInputStart.voice) _toggleListening();
      if (widget.start == SmartInputStart.receipt) _scanReceipt();
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _text.dispose();
    super.dispose();
  }

  // ─── Suara (speech-to-text di perangkat, gratis) ──────────────────────────
  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      if (_text.text.trim().isNotEmpty) _analyze();
      return;
    }
    if (!_speechReady) {
      try {
        _speechReady = await _speech.initialize(
          onStatus: (s) {
            if ((s == 'done' || s == 'notListening') && mounted && _listening) {
              setState(() => _listening = false);
              if (_text.text.trim().isNotEmpty) _analyze();
            }
          },
          onError: (_) => mounted ? setState(() => _listening = false) : null,
        );
      } catch (_) {
        _speechReady = false;
      }
    }
    if (!_speechReady) {
      setState(
        () => _info =
            'Mikrofon atau pengenal suara tidak tersedia di perangkat ini.',
      );
      return;
    }
    setState(() {
      _listening = true;
      _info = null;
    });
    try {
      await _speech.listen(
        // Berhenti otomatis setelah 3 detik diam, maksimal 45 detik.
        listenOptions: SpeechListenOptions(
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 45),
          localeId: 'id_ID',
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (r) => setState(() => _text.text = r.recognizedWords),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _info =
              'Tidak bisa memakai mikrofon. Periksa izin mikrofon untuk PocketFlow.';
        });
      }
    }
  }

  // ─── Analisis teks ────────────────────────────────────────────────────────
  Future<void> _analyze() async {
    final input = _text.text.trim();
    if (input.isEmpty || input == _lastAnalyzed || _busy) return;
    _lastAnalyzed = input;
    setState(() {
      _busy = true;
      _info = null;
      _notice = null;
      _source = 'ai';
    });
    try {
      final res = await ref
          .read(aiParseServiceProvider)
          .parseText(
            input,
            categories: ref.read(categoriesProvider).value ?? const [],
            wallets: ref.read(walletsProvider).value ?? const [],
          );
      final drafts = ref.read(draftEnricherProvider)(res.drafts);
      setState(() {
        _drafts = drafts;
        _notice = res.fallbackReason;
        _info = drafts.isEmpty
            ? 'Tidak menemukan nominal. Coba sebutkan angkanya, mis. "kopi 18rb".'
            : null;
      });
      final ready =
          drafts.isNotEmpty &&
          drafts.every(
            (d) =>
                d.amount > 0 &&
                (d.type == TransactionType.transfer
                    ? d.walletId != null && d.toWalletId != null
                    : d.categoryId != null),
          );
      if (widget.autoSave && ready && mounted) {
        setState(() => _busy = false);
        await _saveAll(withUndo: true);
        return;
      }
      if (widget.autoSave && drafts.isNotEmpty && mounted) {
        setState(
          () => _info = 'Ada yang belum punya kategori. Periksa lalu simpan.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Struk ────────────────────────────────────────────────────────────────
  Future<void> _scanReceipt() async {
    final source = await _pickSource();
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() {
      _busy = true;
      _info = null;
      _notice = null;
      _source = 'ocr';
    });
    try {
      String? ocr;
      if (!kIsWeb && isOnDeviceOcrAvailable) {
        ocr = await recognizeReceiptText(file.path);
      }
      final bytes = ocr == null ? await file.readAsBytes() : null;
      final name = file.name.toLowerCase();
      final res = await ref
          .read(aiParseServiceProvider)
          .parseReceipt(
            ocrText: ocr,
            imageBytes: bytes,
            mimeType: name.endsWith('.png') ? 'image/png' : 'image/jpeg',
            categories: ref.read(categoriesProvider).value ?? const [],
            wallets: ref.read(walletsProvider).value ?? const [],
          );
      final drafts = ref.read(draftEnricherProvider)(res.drafts);
      setState(() {
        _drafts = drafts;
        _notice = res.fallbackReason;
        _info = drafts.isEmpty
            ? (ocr == null && kIsWeb
                  ? 'Struk tidak terbaca. Di web, scan struk membutuhkan AI aktif.'
                  : 'Total di struk tidak terbaca. Coba foto lebih dekat dan terang.')
            : null;
      });
    } catch (e) {
      setState(
        () => _info = ErrorHelper.getHumanReadableMessage(
          e,
          fallback: 'Gagal membaca struk.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ImageSource?> _pickSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Foto struk'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri / screenshot'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Simpan ───────────────────────────────────────────────────────────────
  Future<void> _saveAll({bool withUndo = false}) async {
    setState(() => _busy = true);
    var saved = 0;
    final createdIds = <String>[];
    final txNotifier = ref.read(transactionsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    var merged = 0;
    try {
      for (final d in _drafts) {
        if (d.type == TransactionType.income) {
          final dup = await txNotifier.findSalaryDuplicate(
            amount: d.amount,
            date: d.date,
            text: d.merchant ?? d.note,
          );
          if (dup != null) {
            await txNotifier.mergeIntoSalary(dup, walletId: d.walletId);
            merged++;
            saved++;
            continue;
          }
        }
        await ref
            .read(transactionsProvider.notifier)
            .addTransaction(
              categoryId: d.categoryId,
              type: d.type,
              amount: d.amount,
              transactionDate: d.date,
              description: d.note ?? d.merchant,
              merchant: d.merchant,
              walletId: d.walletId,
              toWalletId: d.toWalletId,
              source: _source,
              externalRef: _source == 'ocr'
                  ? 'ocr:${stableHash('${d.amount}|${d.date.toIso8601String()}|${d.merchant}')}'
                  : null,
            );
        final id = ref.read(transactionsProvider).value?.firstOrNull?.id;
        if (id != null) createdIds.add(id);
        saved++;
      }
      if (!mounted) return;
      final mergedNote = merged > 0
          ? ' Gaji sudah tercatat di Alokasi Gaji, jadi tidak dicatat dua kali.'
          : '';
      final summary = (_drafts.length == 1 && merged == 0)
          ? '${_drafts.first.merchant ?? 'Transaksi'} ${_drafts.first.amount.toRupiah} tersimpan.'
          : '$saved transaksi tersimpan.$mergedNote';
      Navigator.of(context).pop();
      if (withUndo) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(summary),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Batalkan',
              onPressed: () async {
                for (final id in createdIds) {
                  try {
                    await txNotifier.deleteTransaction(id);
                  } catch (_) {}
                }
              },
            ),
          ),
        );
      } else {
        AppTheme.showSuccessSnackBar(context, summary);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drafts = _drafts.sublist(saved);
        _info = ErrorHelper.getHumanReadableMessage(
          e,
          fallback: 'Sebagian gagal disimpan.',
        );
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editing != null) {
      final i = _editing!;
      return DraftEditorSheet(
        key: ValueKey('edit-$i'),
        draft: _drafts[i],
        title: 'Ubah transaksi',
        confirmLabel: 'Selesai',
        onCancel: () => setState(() => _editing = null),
        onSubmit: (d) => setState(() {
          _drafts = [..._drafts]..[i] = d;
          _editing = null;
        }),
      );
    }

    final hasResults = _drafts.isNotEmpty;
    return AppModalScaffold(
      title: widget.autoSave
          ? (_listening ? 'Mendengarkan…' : 'Catat dengan suara')
          : 'Catat pintar',
      subtitle: widget.autoSave
          ? 'Ucapkan saja, mis. "makan siang 25 ribu pakai gopay". Tersimpan otomatis setelah kamu diam 3 detik.'
          : 'Ketik atau ucapkan seperti chat. Contoh: "makan bakso 25rb pakai gopay, parkir 5rb".',
      actions: [
        if (hasResults) ...[
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _drafts = const [];
                    _lastAnalyzed = null;
                  }),
            child: const Text('Ulangi'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _saveAll,
            child: Text(
              _drafts.length == 1
                  ? 'Simpan'
                  : 'Simpan ${_drafts.length} transaksi',
            ),
          ),
        ] else ...[
          AppModalScaffold.cancelButton(context),
          ElevatedButton(
            onPressed: _busy ? null : _analyze,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Baca'),
          ),
        ],
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasResults) ...[
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              autofocus: widget.start == SmartInputStart.text,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _listening
                    ? 'Mendengarkan…'
                    : 'Tulis pengeluaran atau pemasukan',
              ),
              onSubmitted: (_) => _analyze(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _toggleListening,
                    style: _listening
                        ? OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(color: AppTheme.danger),
                          )
                        : null,
                    icon: Icon(
                      _listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                      size: 20,
                    ),
                    label: Text(_listening ? 'Berhenti' : 'Bicara'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _scanReceipt,
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    label: const Text('Scan struk'),
                  ),
                ),
              ],
            ),
          ],
          if (_busy && !hasResults) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_notice != null) ...[
            const SizedBox(height: 12),
            _AiNotice(_notice!),
          ],
          if (_info != null) ...[
            const SizedBox(height: 12),
            Text(_info!, style: Ui.body(size: 12.5)),
          ],
          if (hasResults) ...[
            const SizedBox(height: 4),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _drafts.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 60),
                    _DraftRow(
                      draft: _drafts[i],
                      onTap: () => setState(() => _editing = i),
                      onRemove: () =>
                          setState(() => _drafts = [..._drafts]..removeAt(i)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Ketuk transaksi untuk mengubah kategori, dompet, atau tanggal.',
              style: Ui.body(size: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraftRow extends ConsumerWidget {
  final DraftTransaction draft;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _DraftRow({
    required this.draft,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider).value ?? const [];
    final wallets = ref.watch(walletsProvider).value ?? const [];
    final cat = cats.where((c) => c.id == draft.categoryId).firstOrNull?.name;
    final wallet = wallets
        .where((w) => w.id == draft.walletId)
        .firstOrNull
        ?.name;
    final isIncome = draft.type == TransactionType.income;
    final isTransfer = draft.type == TransactionType.transfer;
    final meta = [
      isTransfer ? 'Transfer' : (cat ?? 'Tanpa kategori'),
      ?wallet,
      dateRelativeId(draft.date),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          children: [
            IconBadge(
              isTransfer
                  ? Icons.swap_horiz_rounded
                  : (isIncome
                        ? Icons.south_west_rounded
                        : Icons.north_east_rounded),
              color: isTransfer
                  ? AppTheme.primary
                  : (isIncome
                        ? const Color(0xFF059669)
                        : AppTheme.textDarkSecondary),
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.merchant ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ui.body(
                      size: 14,
                      color: AppTheme.textDarkPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ui.body(
                      size: 12,
                      color: cat == null && !isTransfer
                          ? AppTheme.warning
                          : AppTheme.textDarkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isTransfer ? '' : (isIncome ? '+' : '−')}${draft.amount.toRupiah}',
              style: Ui.amount(
                size: 14,
                color: isIncome
                    ? const Color(0xFF059669)
                    : AppTheme.textDarkPrimary,
              ),
            ),
            IconButton(
              tooltip: 'Hapus',
              onPressed: onRemove,
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppTheme.textDarkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiNotice extends StatelessWidget {
  final String message;
  const _AiNotice(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5D9A8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Ui.body(size: 12.5, color: AppTheme.textDarkPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
