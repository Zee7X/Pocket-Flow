// lib/core/offline/offline_queue.dart
//
// Mode offline-first sederhana:
// * Transaksi yang gagal dikirim karena tidak ada koneksi disimpan di
//   antrean lokal dan tetap tampil di daftar dengan tanda "Menunggu sinkron".
// * Antrean dikirim ulang otomatis saat koneksi kembali atau aplikasi dibuka.
// * Daftar transaksi per bulan di-cache supaya tetap bisa dilihat offline.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_store.dart';

/// True bila error berasal dari jaringan (tidak ada koneksi, DNS gagal, timeout).
bool isNetworkError(Object e) {
  final s = e.toString();
  return s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException') ||
      s.contains('XMLHttpRequest error') ||
      s.contains('Connection refused') ||
      s.contains('Connection closed') ||
      s.contains('Network is unreachable') ||
      s.contains('TimeoutException') ||
      s.contains('AuthRetryableFetchException');
}

class OfflineQueue {
  final LocalStore? _store;
  final String _userId;

  OfflineQueue(this._store, this._userId);

  String get _queueKey => 'offline_tx_queue_$_userId';
  String _cacheKey(int month, int year) => 'tx_cache_${_userId}_${year}_$month';

  /// Item antrean: map siap insert ke pf_transactions + 'local_id'.
  List<Map<String, dynamic>> pending() {
    final raw = _store?.getJson(_queueKey);
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> enqueue(Map<String, dynamic> item) async {
    final list = pending()..add(item);
    await _store?.setJson(_queueKey, list);
  }

  Future<void> remove(String localId) async {
    final list = pending()..removeWhere((e) => e['local_id'] == localId);
    await _store?.setJson(_queueKey, list);
  }

  List<Map<String, dynamic>>? cachedMonth(int month, int year) {
    final raw = _store?.getJson(_cacheKey(month, year));
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> cacheMonth(
    int month,
    int year,
    List<Map<String, dynamic>> rows,
  ) async {
    await _store?.setJson(_cacheKey(month, year), rows);
  }
}

/// Status koneksi (true = online). Di web/test dianggap online.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  if (kIsWeb) {
    yield true;
    return;
  }
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((x) => x != ConnectivityResult.none);
  try {
    yield online(await c.checkConnectivity());
    yield* c.onConnectivityChanged.map(online);
  } catch (_) {
    yield true;
  }
});
