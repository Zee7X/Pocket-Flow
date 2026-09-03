// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/app.dart';
import 'core/constants/supabase_constants.dart';
import 'core/notifications/notification_service.dart';
import 'core/widgets/error_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Override global ErrorWidget to prevent red screen of death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF4F6FA),
      child: SafeArea(
        child: AppErrorWidget(
          error: details.exception,
          onRetry: () async {
            try {
              await Supabase.instance.client.auth.refreshSession();
            } catch (_) {}
          },
        ),
      ),
    );
  };

  // Initialize Supabase
  if (!SupabaseConstants.isConfigured) {
    debugPrint(
      '⚠️ PERINGATAN: Supabase belum dikonfigurasi! '
      'Pastikan menyalin .env.example ke .env dan menjalankan dengan '
      '--dart-define-from-file=.env',
    );
  }
  try {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      publishableKey: SupabaseConstants.publishableKey,
    );
  } catch (e, stackTrace) {
    debugPrint('Supabase initialization error: $e\n$stackTrace');
  }

  if (!kIsWeb) {
    try {
      // Initialize timezone data for local notifications
      tz.initializeTimeZones();
      await NotificationService().init();
    } catch (e, stackTrace) {
      debugPrint('Notification timezone init error: $e\n$stackTrace');
    }

    try {
      // Force portrait orientation on mobile devices
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (e) {
      debugPrint('Orientation configuration error: $e');
    }
  }

  // Set system UI overlay style for seamless edge-to-edge status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: PocketFlowApp(),
    ),
  );
}
