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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
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
