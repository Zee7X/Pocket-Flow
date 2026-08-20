// lib/core/widgets/cloudpulse_card.dart
import 'package:flutter/material.dart';
import '../../app/theme.dart';

class CloudPulseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final bool hasGlow;

  const CloudPulseCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.hasGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusLarge),
        border: Border.all(color: borderColor ?? AppTheme.borderDark),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusLarge),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
