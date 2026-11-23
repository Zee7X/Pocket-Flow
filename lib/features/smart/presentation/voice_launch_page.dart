// lib/features/smart/presentation/voice_launch_page.dart
//
// Tujuan deep link pocketflow://app/voice: buka Home lalu langsung
// mendengarkan. Dipakai shortcut ikon aplikasi (tekan lama), tombol mic di
// widget Android, dan Siri Shortcuts di iPhone.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import 'smart_input_sheet.dart';

class VoiceLaunchPage extends StatefulWidget {
  const VoiceLaunchPage({super.key});

  @override
  State<VoiceLaunchPage> createState() => _VoiceLaunchPageState();
}

class _VoiceLaunchPageState extends State<VoiceLaunchPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
      // Tunggu Home tampil, lalu buka mode suara di atasnya.
      Future.delayed(const Duration(milliseconds: 350), () {
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null && ctx.mounted) showVoiceCapture(ctx);
      });
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
