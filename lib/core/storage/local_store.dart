// lib/core/storage/local_store.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan key-value lokal (SharedPreferences di Android/iOS,
/// localStorage di web). Dipakai untuk cache offline, antrean sinkron,
/// status peringatan budget, dan preferensi kecil lain.
class LocalStore {
  final SharedPreferences _prefs;
  LocalStore(this._prefs);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  dynamic getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));
}

/// Di-override di main() setelah SharedPreferences siap. Bila belum
/// di-override (mis. di widget test), baca lewat [maybeLocalStoreProvider]
/// yang mengembalikan null.
final localStoreProvider = Provider<LocalStore>((ref) {
  throw StateError('localStoreProvider belum diinisialisasi');
});

/// Membuat LocalStore. Panggil sekali saat startup.
Future<LocalStore> createLocalStore() async {
  final prefs = await SharedPreferences.getInstance();
  return LocalStore(prefs);
}

/// Versi aman untuk dibaca dari provider lain: null bila store belum siap.
final maybeLocalStoreProvider = Provider<LocalStore?>((ref) {
  try {
    return ref.watch(localStoreProvider);
  } catch (_) {
    return null;
  }
});
