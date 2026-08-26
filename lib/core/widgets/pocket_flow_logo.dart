// lib/core/widgets/pocket_flow_logo.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

/// Modern high-contrast typography logo for PocketFlow.
/// Features Royal Blue for 'Pocket' and pure White for 'Flow'
/// with a crisp Royal Blue stroke outline (list) and soft shadow,
/// ensuring 100% legibility and stunning aesthetics without needing a badge container.
class PocketFlowLogo extends StatelessWidget {
  final double size;
  final bool showIcon;

  const PocketFlowLogo({
    super.key,
    this.size = 26,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1D4ED8), // Deep Royal Blue
                  Color(0xFF2563EB), // Primary Electric Blue
                  Color(0xFF0EA5E9), // Cyan Accent
                ],
              ),
              borderRadius: BorderRadius.circular(size * 0.42),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: size * 0.45,
                  offset: Offset(0, size * 0.12),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: size * 0.85,
              ),
            ),
          ),
          SizedBox(width: size * 0.38),
        ],

        // ── Brand Text Combination ──────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "Pocket" in Solid Royal Blue
            Text(
              'Pocket',
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),

            // "Flow" in Elegant Deep Slate Charcoal
            Text(
              'Flow',
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDarkPrimary,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
