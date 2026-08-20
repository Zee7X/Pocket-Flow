// lib/core/widgets/empty_state.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../app/theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, size: 36, color: AppTheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.textDarkSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(180, 44),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
