// lib/features/wallets/presentation/providers/wallets_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/wallet_repository.dart';
import '../../domain/payment_providers.dart';
import '../../domain/wallet.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(supabaseClientProvider));
});

final walletsProvider = AsyncNotifierProvider<WalletsNotifier, List<Wallet>>(
  WalletsNotifier.new,
);

class WalletsNotifier extends AsyncNotifier<List<Wallet>> {
  @override
  Future<List<Wallet>> build() async {
    if (ref.watch(currentUserIdProvider) == null) return const [];
    try {
      return await ref.watch(walletRepositoryProvider).getWallets();
    } catch (_) {
      // Tabel belum dibuat (migrasi belum dijalankan) atau offline:
      // fitur dompet dianggap kosong, aplikasi tetap jalan.
      return const [];
    }
  }

  Future<Wallet> addWallet({
    required String name,
    required WalletKind kind,
    String? providerKey,
    int initialBalance = 0,
    String? color,
  }) async {
    final w = await ref
        .read(walletRepositoryProvider)
        .createWallet(
          name: name,
          kind: kind,
          providerKey: providerKey,
          initialBalance: initialBalance,
          color: color,
          sortOrder: (state.value ?? const []).length,
        );
    state = AsyncValue.data([...(state.value ?? const []), w]);
    return w;
  }

  Future<void> updateWallet({
    required String id,
    required String name,
    required WalletKind kind,
    String? providerKey,
    required int initialBalance,
    String? color,
  }) async {
    await ref
        .read(walletRepositoryProvider)
        .updateWallet(
          id: id,
          name: name,
          kind: kind,
          providerKey: providerKey,
          initialBalance: initialBalance,
          color: color,
        );
    ref.invalidateSelf();
  }

  Future<void> archiveWallet(String id) async {
    await ref.read(walletRepositoryProvider).archiveWallet(id);
    state = AsyncValue.data(
      (state.value ?? const []).where((w) => w.id != id).toList(),
    );
  }

  /// Cari dompet pengguna yang cocok dengan penyedia (mis. 'gopay').
  /// Bila belum ada, buat otomatis supaya transaksi terdeteksi punya dompet.
  Future<Wallet?> ensureForProvider(String? providerKey) async {
    if (providerKey == null) return null;
    final existing = (state.value ?? const [])
        .where((w) => w.providerKey == providerKey)
        .firstOrNull;
    if (existing != null) return existing;
    final p = PaymentProviders.byKey(providerKey);
    if (p == null) return null;
    try {
      return await addWallet(
        name: p.name,
        kind: p.kind,
        providerKey: p.key,
        color: colorToHex(p.color),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Total saldo aset (tanpa kartu kredit/paylater).
final totalWalletBalanceProvider = Provider<int>((ref) {
  final wallets = ref.watch(walletsProvider).value ?? const [];
  return wallets
      .where((w) => !w.kind.isLiability)
      .fold<int>(0, (s, w) => s + w.balance);
});
