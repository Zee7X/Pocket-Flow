// lib/core/utils/error_helper.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHelper {
  /// Converts any raw error or exception into a clean, friendly Indonesian message
  static String getHumanReadableMessage(Object? error, {String fallback = 'Terjadi kendala pada sistem. Silakan coba lagi.'}) {
    if (error == null) return fallback;

    final str = error.toString().toLowerCase();

    // 1. PostgrestException specific handling
    if (error is PostgrestException) {
      if (error.code == '23505' || str.contains('duplicate key') || str.contains('already exists')) {
        return 'Data untuk periode atau nama ini sudah pernah dibuat.';
      }
      if (error.code == '23503' || str.contains('foreign key')) {
        return 'Data referensi terkait tidak ditemukan atau telah dihapus.';
      }
      if (error.code == '42501' || str.contains('permission denied')) {
        return 'Anda tidak memiliki izin untuk melakukan aksi ini.';
      }
      if (error.message.isNotEmpty && !error.message.contains('{') && !error.message.contains('SQL')) {
        return error.message;
      }
    }

    // 2. Auth & JWT / Token Errors
    if (str.contains('pgrst303') ||
        str.contains('jwt issued at future') ||
        str.contains('token is expired') ||
        str.contains('invalid claim') ||
        str.contains('not authenticated')) {
      return 'Sesi login belum sinkron atau kedaluwarsa. Silakan muat ulang atau coba beberapa saat lagi.';
    }

    // 3. Network & Connection Errors
    if (str.contains('socketexception') ||
        str.contains('clientexception') ||
        str.contains('timeoutexception') ||
        str.contains('failed host lookup') ||
        str.contains('network') ||
        str.contains('offline') ||
        str.contains('connection refused') ||
        str.contains('connection closed') ||
        str.contains('xmlhttprequest error')) {
      return 'Koneksi internet terputus. Pastikan perangkat Anda terhubung ke internet.';
    }

    // 4. Duplicate unique constraint text in string
    if (str.contains('duplicate key') || str.contains('already exists') || str.contains('unique constraint')) {
      return 'Data untuk periode atau nama ini sudah ada di sistem.';
    }

    // 5. Clean up standard Dart Exception / FormatException
    var clean = error.toString();
    if (clean.startsWith('Exception: ')) {
      clean = clean.substring(11).trim();
    } else if (clean.startsWith('FormatException: ')) {
      clean = 'Format data yang dimasukkan tidak valid.';
    }

    // If it still contains raw developer stack/code, return fallback
    if (clean.contains('PostgrestException') ||
        clean.contains('AuthException') ||
        clean.contains('details:') ||
        clean.contains('hint:')) {
      return fallback;
    }

    return clean.isNotEmpty ? clean : fallback;
  }
}
