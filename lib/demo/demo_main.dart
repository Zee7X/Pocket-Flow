// lib/demo/demo_main.dart
//
// Entry point khusus PREVIEW: menjalankan PocketFlow dengan data contoh
// di memori, tanpa koneksi Supabase. Dipakai untuk melihat tampilan di
// browser / emulator sebelum backend disambungkan.
//
//   flutter run -d chrome -t lib/demo/demo_main.dart
//
// Data tidak disimpan ke mana pun. Aksi tulis (simpan transaksi, dll.)
// hanya mengubah state di memori selama aplikasi terbuka.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../core/storage/local_store.dart';
import 'demo_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await createLocalStore();
  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        ...buildDemoOverrides(),
      ],
      child: const PocketFlowApp(),
    ),
  );
}
