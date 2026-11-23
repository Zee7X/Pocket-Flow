// lib/features/capture/data/capture_channel.dart
//
// Jembatan ke kode native Android (PaymentNotificationListener + widget).
// Di iOS / web semua method mengembalikan nilai aman (tidak didukung).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/capture_models.dart';

class CaptureChannel {
  static const _channel = MethodChannel('pocketflow/capture');

  final _captured = StreamController<void>.broadcast();
  bool _handlerSet = false;

  /// Notifikasi baru tertangkap saat aplikasi terbuka.
  Stream<void> get onCaptured {
    _ensureHandler();
    return _captured.stream;
  }

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  void _ensureHandler() {
    if (_handlerSet || !isSupported) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCaptured') _captured.add(null);
      return null;
    });
  }

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('CaptureChannel.$method: $e');
      return null;
    }
  }

  Future<bool> isPermissionGranted() async =>
      await _invoke<bool>('isPermissionGranted') ?? false;

  Future<void> openPermissionSettings() => _invoke('openPermissionSettings');

  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;

  Future<void> openBatterySettings() => _invoke('openBatterySettings');

  /// Ambil semua notifikasi yang tertangkap sejak terakhir dibaca, lalu
  /// hapus dari penyimpanan native.
  Future<List<CapturedNotification>> drain() async {
    final list = await _invoke<List<Object?>>('drain') ?? const [];
    return list
        .whereType<Map<Object?, Object?>>()
        .map(CapturedNotification.fromMap)
        .toList();
  }

  /// Paket aplikasi yang boleh dibaca notifikasinya.
  Future<void> setAllowedPackages(List<String> packages) =>
      _invoke('setAllowedPackages', {'packages': packages});

  /// Data untuk widget layar utama + teks notifikasi "transaksi terdeteksi".
  Future<void> updateWidget({
    required int safeToday,
    required int spentToday,
    required int dailyQuota,
  }) => _invoke('updateWidget', {
    'safeToday': safeToday,
    'spentToday': spentToday,
    'dailyQuota': dailyQuota,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });
}
