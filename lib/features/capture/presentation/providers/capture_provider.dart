// lib/features/capture/presentation/providers/capture_provider.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../smart/domain/category_suggester.dart';
import '../../../smart/presentation/providers/smart_providers.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';
import '../../../wallets/domain/payment_providers.dart';
import '../../../wallets/presentation/providers/wallets_provider.dart';
import '../../data/capture_channel.dart';
import '../../data/pending_repository.dart';
import '../../domain/capture_models.dart';
import '../../domain/notification_parser.dart';
import '../../domain/pending_capture.dart';
import '../../domain/transfer_matcher.dart';

final captureChannelProvider = Provider<CaptureChannel>(
  (ref) => CaptureChannel(),
);

final pendingRepositoryProvider = Provider<PendingRepository>((ref) {
  return PendingRepository(ref.watch(supabaseClientProvider));
});

// ─── Pengaturan deteksi ──────────────────────────────────────────────────────
class CaptureSettings {
  /// Baca notifikasi aplikasi SMS (SMS bank). Default mati.
  final bool readSms;

  /// Simpan langsung tanpa ditinjau bila merchant sudah punya aturan kategori
  /// dan tingkat keyakinan tinggi.
  final bool autoConfirm;

  /// Paket yang dimatikan pengguna secara manual.
  final Set<String> disabledProviders;

  const CaptureSettings({
    this.readSms = false,
    this.autoConfirm = false,
    this.disabledProviders = const {},
  });

  List<String> get allowedPackages => [
    for (final p in PaymentProviders.all)
      if (!disabledProviders.contains(p.key)) ...p.androidPackages,
    if (readSms) ...PaymentProviders.smsPackages,
  ];

  Map<String, dynamic> toJson() => {
    'readSms': readSms,
    'autoConfirm': autoConfirm,
    'disabled': disabledProviders.toList(),
  };

  factory CaptureSettings.fromJson(dynamic j) {
    if (j is! Map) return const CaptureSettings();
    return CaptureSettings(
      readSms: j['readSms'] == true,
      autoConfirm: j['autoConfirm'] == true,
      disabledProviders: {
        ...((j['disabled'] as List?) ?? const []).cast<String>(),
      },
    );
  }

  CaptureSettings copyWith({
    bool? readSms,
    bool? autoConfirm,
    Set<String>? disabledProviders,
  }) => CaptureSettings(
    readSms: readSms ?? this.readSms,
    autoConfirm: autoConfirm ?? this.autoConfirm,
    disabledProviders: disabledProviders ?? this.disabledProviders,
  );
}

final captureSettingsProvider =
    NotifierProvider<CaptureSettingsNotifier, CaptureSettings>(
      CaptureSettingsNotifier.new,
    );

class CaptureSettingsNotifier extends Notifier<CaptureSettings> {
  static const _key = 'capture_settings';

  @override
  CaptureSettings build() {
    final store = ref.watch(maybeLocalStoreProvider);
    return CaptureSettings.fromJson(store?.getJson(_key));
  }

  Future<void> update(CaptureSettings s) async {
    state = s;
    await ref.read(maybeLocalStoreProvider)?.setJson(_key, s.toJson());
    await ref
        .read(captureChannelProvider)
        .setAllowedPackages(s.allowedPackages);
  }
}

/// Status izin akses notifikasi (Android).
final capturePermissionProvider = FutureProvider<bool>((ref) async {
  return ref.watch(captureChannelProvider).isPermissionGranted();
});

// ─── Inbox "Perlu Ditinjau" ──────────────────────────────────────────────────
final pendingCapturesProvider =
    AsyncNotifierProvider<PendingCapturesNotifier, List<PendingCapture>>(
      PendingCapturesNotifier.new,
    );

class PendingCapturesNotifier extends AsyncNotifier<List<PendingCapture>> {
  @override
  Future<List<PendingCapture>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    try {
      return await ref.watch(pendingRepositoryProvider).getPending();
    } catch (_) {
      return const [];
    }
  }

  /// Ambil notifikasi dari Android, parse, dan masukkan ke inbox.
  Future<int> drainNative() async {
    final raw = await ref.read(captureChannelProvider).drain();
    if (raw.isEmpty) return 0;
    const parser = NotificationParser();
    final parsed = raw.map(parser.parse).whereType<ParsedCapture>().toList();
    return ingest(parsed);
  }

  /// Masukkan kandidat transaksi (dari notifikasi, OCR, shortcut, tempel teks,
  /// atau AI). Mengembalikan jumlah item baru.
  Future<int> ingest(List<ParsedCapture> items) async {
    if (items.isEmpty) return 0;
    const matcher = TransferMatcher();
    var batch = matcher.merge(items);
    final repo = ref.read(pendingRepositoryProvider);
    final existing = state.value ?? await future;

    // Pasangkan dengan item lama yang masih menunggu (mis. notifikasi bank
    // datang lebih dulu, notifikasi e-wallet menyusul).
    final remaining = <ParsedCapture>[];
    for (final item in batch) {
      final match = _pairWithExisting(item, existing, matcher);
      if (match == null) {
        remaining.add(item);
        continue;
      }
      final (row, incomingIsNew) = match;
      final wallets = ref.read(walletsProvider.notifier);
      final from = await wallets.ensureForProvider(
        incomingIsNew ? row.providerKey : item.providerKey,
      );
      final to = await wallets.ensureForProvider(
        incomingIsNew ? item.providerKey : row.providerKey,
      );
      try {
        await repo.markTransfer(
          id: row.id,
          fromWalletId: from?.id,
          toWalletId: to?.id,
          amount: incomingIsNew ? item.amount : row.amount,
        );
      } catch (_) {}
    }
    batch = remaining;

    final suggester = ref.read(categorySuggesterProvider);
    final settings = ref.read(captureSettingsProvider);
    final rows = <Map<String, dynamic>>[];
    var autoSaved = 0;

    for (final item in batch) {
      final wallets = ref.read(walletsProvider.notifier);
      final wallet = await wallets.ensureForProvider(item.providerKey);
      final toWallet = item.type == TransactionType.transfer
          ? await wallets.ensureForProvider(item.counterpartyProviderKey)
          : null;
      final suggestion = item.type == TransactionType.transfer
          ? null
          : suggester.suggest(
              merchant: item.merchant,
              isIncome: item.type == TransactionType.income,
            );

      // Catat otomatis bila diizinkan dan kategori berasal dari aturan pengguna.
      if (settings.autoConfirm &&
          item.confidence >= 0.8 &&
          (item.type == TransactionType.transfer ||
              suggestion?.reason == 'rule')) {
        try {
          await ref
              .read(transactionsProvider.notifier)
              .addTransaction(
                categoryId: suggestion?.categoryId,
                type: item.type,
                amount: item.amount,
                transactionDate: item.occurredAt,
                description: item.merchant,
                merchant: item.merchant,
                walletId: wallet?.id,
                toWalletId: toWallet?.id,
                source: item.source,
                externalRef: item.dedupeHash,
              );
          autoSaved++;
          continue;
        } catch (_) {
          // Gagal / duplikat: biarkan masuk inbox.
        }
      }

      rows.add({
        'source': item.source,
        'source_app': item.sourceApp,
        'provider_key': item.providerKey,
        'type': item.type.toDbString(),
        'amount': item.amount,
        'merchant': item.merchant,
        'occurred_at': item.occurredAt.toUtc().toIso8601String(),
        'suggested_category_id': suggestion?.categoryId,
        'suggested_wallet_id': wallet?.id,
        'to_wallet_id': toWallet?.id,
        'confidence': double.parse(item.confidence.toStringAsFixed(2)),
        'dedupe_hash': item.dedupeHash,
      });
    }

    await repo.insertMany(rows);
    ref.invalidateSelf();
    await future;
    return rows.length + autoSaved;
  }

  (PendingCapture, bool)? _pairWithExisting(
    ParsedCapture item,
    List<PendingCapture> existing,
    TransferMatcher m,
  ) {
    for (final row in existing) {
      if (row.type == TransactionType.transfer) continue;
      final asParsed = ParsedCapture(
        type: row.type,
        amount: row.amount,
        merchant: row.merchant,
        providerKey: row.providerKey,
        occurredAt: row.occurredAt,
        confidence: row.confidence,
        dedupeHash: row.dedupeHash,
        source: row.source,
        isTopUp: (row.merchant ?? '').toLowerCase().contains('top up'),
        counterpartyProviderKey: PaymentProviders.byText(
          row.merchant ?? '',
        )?.key,
      );
      if (m.isPair(asParsed, item)) {
        return (row, true); // row keluar, item masuk
      }
      if (m.isPair(item, asParsed)) {
        return (row, false); // item keluar, row masuk
      }
    }
    return null;
  }

  /// Simpan item inbox sebagai transaksi.
  Future<void> confirm(
    PendingCapture item, {
    required TransactionType type,
    required int amount,
    required DateTime date,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    String? merchant,
    String? note,
  }) async {
    String? txId;
    try {
      await ref
          .read(transactionsProvider.notifier)
          .addTransaction(
            categoryId: categoryId,
            type: type,
            amount: amount,
            transactionDate: date,
            description: note ?? merchant,
            merchant: merchant,
            walletId: walletId,
            toWalletId: toWalletId,
            source: item.source == 'ai' ? 'ai' : item.source,
            externalRef: item.dedupeHash,
          );
      txId = ref.read(transactionsProvider).value?.firstOrNull?.id;
    } catch (e) {
      // Duplikat external_ref berarti sudah pernah tersimpan: anggap selesai.
      if (!e.toString().contains('duplicate') &&
          !e.toString().contains('23505')) {
        rethrow;
      }
    }
    if (merchant != null && categoryId != null) {
      ref
          .read(merchantRulesProvider.notifier)
          .learn(merchant, categoryId, walletId: walletId);
    }
    await ref
        .read(pendingRepositoryProvider)
        .setStatus(
          item.id,
          'confirmed',
          transactionId: txId != null && !txId.startsWith('local-')
              ? txId
              : null,
        );
    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != item.id).toList(),
    );
  }

  Future<void> dismiss(PendingCapture item) async {
    await ref.read(pendingRepositoryProvider).setStatus(item.id, 'dismissed');
    state = AsyncValue.data(
      (state.value ?? []).where((p) => p.id != item.id).toList(),
    );
  }

  /// Konfirmasi semua item yang sudah punya kategori (atau transfer).
  Future<int> confirmAllReady() async {
    var n = 0;
    for (final p in [...(state.value ?? const <PendingCapture>[])]) {
      final ready =
          p.type == TransactionType.transfer || p.suggestedCategoryId != null;
      if (!ready) continue;
      try {
        await confirm(
          p,
          type: p.type,
          amount: p.amount,
          date: p.occurredAt,
          categoryId: p.suggestedCategoryId,
          walletId: p.suggestedWalletId,
          toWalletId: p.toWalletId,
          merchant: p.merchant,
        );
        n++;
      } catch (_) {}
    }
    return n;
  }
}

final pendingCountProvider = Provider<int>((ref) {
  return ref.watch(pendingCapturesProvider).value?.length ?? 0;
});

/// Helper: kunci merchant dipakai juga di UI.
String captureMerchantKey(String? m) => m == null ? '' : merchantKey(m);
