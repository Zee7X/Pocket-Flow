// lib/core/widgets/app_dropdown_field.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

/// Ultra-Modern Neo-Banking Dropdown Form Field for PocketFlow.
/// Provides rounded floating popup menus, custom chevron icons,
/// rich item layouts (icon badges, titles, subtitles, tags), and seamless validation.
class AppDropdownFormField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(T?)? validator;
  final bool isExpanded;
  final double? menuMaxHeight;
  final bool enabled;
  final List<Widget> Function(BuildContext)? selectedItemBuilder;
  final EdgeInsetsGeometry? contentPadding;
  final FocusNode? focusNode;

  const AppDropdownFormField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.isExpanded = true,
    this.menuMaxHeight = 360,
    this.enabled = true,
    this.selectedItemBuilder,
    this.contentPadding,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    // Smart selected item builder: ensures closed field displays clean single-line title
    // while open popup displays rich multi-line card with full details.
    final effectiveSelectedItemBuilder = selectedItemBuilder ??
        (BuildContext ctx) {
          return items.map<Widget>((DropdownMenuItem<T> item) {
            final child = item.child;
            if (child is AppDropdownItemContent) {
              return Row(
                children: [
                  if (child.icon != null) ...[
                    Icon(
                      child.icon,
                      size: 18,
                      color: child.iconColor ?? AppTheme.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      child.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDarkPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (child.badgeText != null && child.badgeText!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (child.badgeColor ?? AppTheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        child.badgeText!,
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: child.badgeColor ?? AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }
            return child;
          }).toList();
        };

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      isExpanded: isExpanded,
      focusNode: focusNode,
      selectedItemBuilder: effectiveSelectedItemBuilder,
      menuMaxHeight: menuMaxHeight,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      dropdownColor: AppTheme.surfaceLight,
      elevation: 8,
      enableFeedback: true,
      alignment: AlignmentDirectional.centerStart,
      icon: suffixIcon ??
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
      style: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textDarkPrimary,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: prefixIcon,
              )
            : null,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 40,
        ),
        filled: true,
        fillColor: enabled ? AppTheme.surfaceLightAlt : const Color(0xFFF1F5F9),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
      ),
    );
  }
}

/// Rich Item Widget for Dropdown Menu Items
/// Features icon avatar with soft pastel background, primary title, subtitle, and badge.
class AppDropdownItemContent extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final String title;
  final String? subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final String? trailingText;
  final bool isSelected;

  const AppDropdownItemContent({
    super.key,
    this.icon,
    this.iconColor,
    this.iconBgColor,
    required this.title,
    this.subtitle,
    this.badgeText,
    this.badgeColor,
    this.trailingText,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppTheme.primary;
    final effectiveIconBgColor = iconBgColor ?? AppTheme.pastelBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveIconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: effectiveIconColor),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: AppTheme.textDarkPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null && badgeText!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? AppTheme.primary)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          badgeText!,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor ?? AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.textDarkSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailingText != null && trailingText!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              trailingText!,
              style: AppTheme.monoCurrency(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
