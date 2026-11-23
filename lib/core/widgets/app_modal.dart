// lib/core/widgets/app_modal.dart
//
// Satu komponen modal untuk seluruh aplikasi.
//
// * Layar sempit (HP): bottom sheet selebar layar, tinggi mengikuti isi,
//   maksimal 92% layar, ikut naik saat keyboard muncul.
// * Layar lebar (tablet/web): dialog di tengah, lebar maksimal 480.
//
// Struktur selalu sama: header tetap (judul + tombol tutup), isi yang bisa
// di-scroll, dan footer tetap untuk tombol aksi. Isi tidak pernah terpotong
// karena hanya bagian tengah yang scroll.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

enum AppModalMode { sheet, dialog }

class AppModalPresentation extends InheritedWidget {
  final AppModalMode mode;

  const AppModalPresentation({
    super.key,
    required this.mode,
    required super.child,
  });

  static AppModalMode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppModalPresentation>()?.mode;

  @override
  bool updateShouldNotify(AppModalPresentation oldWidget) =>
      oldWidget.mode != mode;
}

/// Breakpoint di atas ini modal tampil sebagai dialog.
const double kAppModalDialogBreakpoint = 600;

Future<T?> showAppModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool isDismissible = true,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= kAppModalDialogBreakpoint;
  if (isWide) {
    return showDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      barrierDismissible: isDismissible,
      builder: (ctx) => AppModalPresentation(
        mode: AppModalMode.dialog,
        child: Builder(builder: builder),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => AppModalPresentation(
      mode: AppModalMode.sheet,
      child: Builder(builder: builder),
    ),
  );
}

/// Kerangka isi modal. Dipakai oleh semua form/sheet.
class AppModalScaffold extends StatelessWidget {
  final String title;

  /// Judul kustom (menggantikan [title] bila diisi).
  final Widget? titleWidget;
  final String? subtitle;
  final Widget child;

  /// Tombol di footer. Biasanya [AppModalScaffold.cancelButton] + tombol utama.
  final List<Widget> actions;
  final EdgeInsetsGeometry bodyPadding;
  final bool showCloseButton;

  const AppModalScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    required this.child,
    this.actions = const [],
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
    this.showCloseButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final mode = AppModalPresentation.maybeOf(context) ?? AppModalMode.dialog;
    final media = MediaQuery.of(context);

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == AppModalMode.sheet)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        _Header(
          title: title,
          titleWidget: titleWidget,
          subtitle: subtitle,
          showClose: showCloseButton,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: bodyPadding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: child,
          ),
        ),
        if (actions.isNotEmpty)
          _Footer(
            actions: actions,
            bottomPadding: mode == AppModalMode.sheet
                ? media.padding.bottom
                : 0,
          ),
      ],
    );

    if (mode == AppModalMode.sheet) {
      final maxHeight = (media.size.height - media.viewInsets.bottom) * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Material(
            color: AppTheme.surfaceLight,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: body,
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceLight,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: body,
      ),
    );
  }

  /// Tombol batal standar untuk footer.
  static Widget cancelButton(BuildContext context, {String label = 'Batal'}) {
    return OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(label),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final bool showClose;

  const _Header({
    required this.title,
    this.titleWidget,
    this.subtitle,
    required this.showClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefaultTextStyle.merge(
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDarkPrimary,
                      letterSpacing: -0.3,
                    ),
                    child: titleWidget ?? Text(title),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppTheme.textDarkSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showClose)
            IconButton(
              tooltip: 'Tutup',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.close_rounded,
                size: 22,
                color: AppTheme.textDarkSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final List<Widget> actions;
  final double bottomPadding;

  const _Footer({required this.actions, required this.bottomPadding});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        border: Border(top: BorderSide(color: AppTheme.borderLightSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPadding),
        child: Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                flex: i == actions.length - 1 && actions.length > 1 ? 2 : 1,
                child: SizedBox(height: 48, child: actions[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog konfirmasi singkat (hapus, keluar, dll). Mengembalikan true bila
/// pengguna menekan tombol konfirmasi.
Future<bool> showAppConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Ya, lanjutkan',
  String cancelLabel = 'Batal',
  bool destructive = false,
}) async {
  final result = await showAppModal<bool>(
    context: context,
    builder: (ctx) => AppModalScaffold(
      title: title,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: destructive
              ? ElevatedButton.styleFrom(backgroundColor: AppTheme.danger)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(
        message,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: AppTheme.textDarkSecondary,
        ),
      ),
    ),
  );
  return result ?? false;
}

/// Label kecil di atas field dalam form modal.
class AppFieldLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AppFieldLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDarkSecondary,
              ),
            ),
          ),
          if (trailing != null) Flexible(child: trailing!),
        ],
      ),
    );
  }
}

/// Pengganti [AlertDialog] dengan API yang sama, tetapi tampil memakai
/// kerangka [AppModalScaffold] (header & footer tetap, isi bisa scroll,
/// bottom sheet di HP). Parameter gaya AlertDialog lama diterima tetapi
/// diabaikan supaya tampilan seragam.
class AppAlertModal extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  const AppAlertModal({
    super.key,
    this.title,
    this.content,
    this.actions,
    // Diabaikan (kompatibilitas dengan AlertDialog):
    bool scrollable = false,
    Color? backgroundColor,
    Color? surfaceTintColor,
    ShapeBorder? shape,
    EdgeInsets? insetPadding,
    EdgeInsetsGeometry? contentPadding,
    EdgeInsetsGeometry? titlePadding,
    EdgeInsetsGeometry? actionsPadding,
    double? actionsOverflowButtonSpacing,
    MainAxisAlignment? actionsAlignment,
    Widget? icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppModalScaffold(
      title: '',
      titleWidget: title,
      actions: actions ?? const [],
      child: content ?? const SizedBox.shrink(),
    );
  }
}
