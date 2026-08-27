// lib/core/widgets/error_state.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app/theme.dart';
import '../utils/error_helper.dart';

class AppErrorWidget extends StatefulWidget {
  final Object? error;
  final Future<void> Function()? onRetry;
  final String? title;
  final String? message;
  final String retryLabel;
  final bool compact;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  const AppErrorWidget({
    super.key,
    this.error,
    this.onRetry,
    this.title,
    this.message,
    this.retryLabel = 'Coba Lagi',
    this.compact = false,
    this.icon,
    this.padding,
  });

  @override
  State<AppErrorWidget> createState() => _AppErrorWidgetState();
}

class _AppErrorWidgetState extends State<AppErrorWidget> {
  bool _isRetrying = false;

  ({IconData icon, String title, String message, Color tintColor, Color bgColor}) _getDiagnostics() {
    final errStr = widget.error?.toString().toLowerCase() ?? '';

    // 1. Check for PGRST303 / JWT issued at future / token clock desync
    if (errStr.contains('pgrst303') ||
        errStr.contains('jwt issued at future') ||
        errStr.contains('jwt') && errStr.contains('future')) {
      return (
        icon: widget.icon ?? Icons.sync_problem_rounded,
        title: widget.title ?? 'Sesi / Waktu Belum Sinkron',
        message: widget.message ??
            'Sesi login terganggu akibat ketidakcocokan jam perangkat dengan server Supabase. Pastikan jam perangkat otomatis, lalu coba muat ulang.',
        tintColor: AppTheme.warning,
        bgColor: AppTheme.pastelYellow,
      );
    }

    // 2. Check for Network / Socket / Offline errors
    if (errStr.contains('socketexception') ||
        errStr.contains('clientexception') ||
        errStr.contains('timeoutexception') ||
        errStr.contains('network') ||
        errStr.contains('offline') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('failed to fetch') ||
        errStr.contains('connection refused') ||
        errStr.contains('connection closed') ||
        errStr.contains('handshake') ||
        errStr.contains('xmlhttprequest error')) {
      return (
        icon: widget.icon ?? Icons.wifi_off_rounded,
        title: widget.title ?? 'Koneksi Terputus',
        message: widget.message ??
            'Tidak dapat terhubung ke server. Periksa sambungan internet Anda lalu coba lagi.',
        tintColor: AppTheme.danger,
        bgColor: AppTheme.pastelRed,
      );
    }

    // 3. Check for Duplicate Constraint / Already Exists
    if (errStr.contains('duplicate key') ||
        errStr.contains('already exists') ||
        errStr.contains('23505')) {
      return (
        icon: widget.icon ?? Icons.info_outline_rounded,
        title: widget.title ?? 'Data Sudah Ada',
        message: widget.message ??
            'Data untuk periode atau nama ini sudah pernah dibuat sebelumnya.',
        tintColor: AppTheme.primary,
        bgColor: AppTheme.pastelBlue,
      );
    }

    // 4. Check for Auth / Expired Token / 401 / 403
    if (errStr.contains('authexception') ||
        errStr.contains('401') ||
        errStr.contains('403') ||
        errStr.contains('unauthorized')) {
      return (
        icon: widget.icon ?? Icons.lock_clock_outlined,
        title: widget.title ?? 'Sesi Kedaluwarsa',
        message: widget.message ??
            'Sesi login Anda telah berakhir atau memerlukan otentikasi ulang. Silakan segarkan data.',
        tintColor: AppTheme.primary,
        bgColor: AppTheme.pastelBlue,
      );
    }

    // 5. General fallback error with human-readable formatting
    return (
      icon: widget.icon ?? Icons.cloud_off_rounded,
      title: widget.title ?? 'Gagal Memuat Data',
      message: widget.message ??
          ErrorHelper.getHumanReadableMessage(widget.error,
              fallback: 'Terjadi kendala saat mengambil data terbaru. Silakan coba beberapa saat lagi.'),
      tintColor: AppTheme.danger,
      bgColor: AppTheme.pastelRed,
    );
  }

  Future<void> _handleRetry() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    try {
      // If error might be JWT related, proactively refresh Supabase session
      final errStr = widget.error?.toString().toLowerCase() ?? '';
      if (errStr.contains('pgrst303') ||
          errStr.contains('jwt') ||
          errStr.contains('authexception')) {
        try {
          await Supabase.instance.client.auth.refreshSession();
        } catch (_) {}
      }

      if (widget.onRetry != null) {
        await widget.onRetry!();
      }
    } catch (_) {
      // Handled by riverpod / caller
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diag = _getDiagnostics();

    if (widget.compact) {
      return Container(
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: diag.bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: diag.tintColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(diag.icon, color: diag.tintColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    diag.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    diag.message,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      color: AppTheme.textDarkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isRetrying ? null : _handleRetry,
                tooltip: widget.retryLabel,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.refresh_rounded, color: diag.tintColor, size: 20),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: diag.bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: diag.tintColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(diag.icon, size: 34, color: diag.tintColor),
            ),
            const SizedBox(height: 18),
            Text(
              diag.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDarkPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                diag.message,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppTheme.textDarkSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _handleRetry,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_isRetrying ? 'Memuat...' : widget.retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  elevation: 0,
                ),
              ),
            ],
            if (kDebugMode && widget.error != null) ...[
              const SizedBox(height: 16),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    'Detail Debug Error',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.textDarkMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLightAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: SelectableText(
                        widget.error.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
