// lib/core/widgets/ui.dart
//
// Komponen UI dasar yang dipakai halaman-halaman baru. Gayanya sengaja datar:
// kartu putih dengan garis tipis, tanpa gradien atau bayangan tebal, satu
// warna aksen, dan angka memakai tabular figures supaya rata.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../extensions/currency_extension.dart';

class Ui {
  static const border = Color(0xFFE6EAF0);
  static const radius = 16.0;

  static TextStyle title({
    double size = 15,
    Color color = AppTheme.textDarkPrimary,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color,
    letterSpacing: -0.2,
  );

  static TextStyle body({
    double size = 13.5,
    Color color = AppTheme.textDarkSecondary,
    FontWeight weight = FontWeight.w400,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.4,
  );

  static TextStyle amount({
    double size = 15,
    Color color = AppTheme.textDarkPrimary,
    FontWeight weight = FontWeight.w600,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: -0.2,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Kartu datar standar.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppTheme.surfaceLight,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Ui.radius),
        side: const BorderSide(color: Ui.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Ui.title(size: 16))),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Ikon bulat kecil dengan latar tipis.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBadge(
    this.icon, {
    super.key,
    this.color = AppTheme.primary,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Baris list standar: ikon, judul, subjudul, trailing.
class ListRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const ListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Ui.body(
                      size: 14,
                      color: AppTheme.textDarkPrimary,
                      weight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Ui.body(size: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Teks nominal berwarna sesuai arah.
class MoneyText extends StatelessWidget {
  final int amount;
  final bool? isIncome;
  final double size;
  final bool showSign;

  const MoneyText(
    this.amount, {
    super.key,
    this.isIncome,
    this.size = 14.5,
    this.showSign = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = isIncome == null
        ? AppTheme.textDarkPrimary
        : (isIncome! ? const Color(0xFF059669) : AppTheme.textDarkPrimary);
    final sign = !showSign || isIncome == null ? '' : (isIncome! ? '+' : '−');
    return Text(
      '$sign${amount.toRupiah}',
      style: Ui.amount(size: size, color: color),
    );
  }
}

/// Pilihan berbentuk chip (pengganti dropdown di dalam modal).
class ChoiceChips<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final IconData? Function(T)? icon;
  final ValueChanged<T?> onChanged;
  final bool allowDeselect;

  const ChoiceChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.icon,
    this.allowDeselect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          _Chip(
            label: label(v),
            icon: icon?.call(v),
            selected: v == selected,
            onTap: () => onChanged(v == selected && allowDeselect ? null : v),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.primary : AppTheme.textDarkPrimary;
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.08)
          : AppTheme.surfaceLight,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppTheme.primary : Ui.border,
          width: selected ? 1.3 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Ui.body(
                    size: 13,
                    color: fg,
                    weight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented control sederhana (Pengeluaran / Pemasukan / Transfer).
class Segmented<T> extends StatelessWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  const Segmented({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: v == value
                        ? AppTheme.surfaceLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: v == value
                        ? const [
                            BoxShadow(
                              color: Color(0x140F172A),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: Ui.body(
                      size: 13,
                      color: v == value
                          ? AppTheme.textDarkPrimary
                          : AppTheme.textDarkSecondary,
                      weight: v == value ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keadaan kosong yang ringkas.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.textDarkMuted),
          const SizedBox(height: 12),
          Text(title, style: Ui.title(), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: Ui.body(), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// AppBar polos untuk halaman sekunder.
PreferredSizeWidget plainAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    backgroundColor: AppTheme.canvasLight,
    actions: actions,
  );
}
