// lib/app/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CloudPulse Design System Implementation
/// Philosophy: Calm confidence — generous whitespace, soft rounded surfaces,
/// sky-to-violet gradient language evoking reliability and uptime.
class AppTheme {
  // ─── CloudPulse Palette ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF0EA5E9); // Sky Blue (Primary actions, healthy status)
  static const Color primaryHover = Color(0xFF0284C7);
  static const Color primaryActive = Color(0xFF0369A1);
  static const Color secondary = Color(0xFF8B5CF6); // Violet (Accent highlights, graph gradients)
  static const Color tertiary = Color(0xFF14B8A6); // Teal (Positive metrics, throughput)

  // Light Mode Canvas & Surfaces
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderLightHover = Color(0xFFCBD5E1);

  // Dark Mode Canvas & Surfaces
  static const Color bgDark = Color(0xFF0B0F19); // Deep Slate Dark
  static const Color surfaceDark = Color(0xFF111827); // Dark Card Surface
  static const Color surfaceDarkAlt = Color(0xFF1E293B); // Dark Input / Alt
  static const Color borderDark = Color(0xFF334155);

  // Semantic Status Colors
  static const Color success = Color(0xFF22C55E); // Positive / Healthy
  static const Color warning = Color(0xFFEAB308); // Degraded / Approaching limit
  static const Color danger = Color(0xFFEF4444); // Critical / Error
  static const Color info = Color(0xFF0EA5E9); // General info

  // Text Colors (Dark Mode)
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textDarkMuted = Color(0xFF64748B);

  // Text Colors (Light Mode)
  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF64748B);
  static const Color textLightMuted = Color(0xFF94A3B8);

  // ─── CloudPulse Gradients ────────────────────────────────────────────────
  static const LinearGradient skyToViolet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static LinearGradient subtleGlowGradient({bool isDark = true}) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                primary.withValues(alpha: 0.18),
                secondary.withValues(alpha: 0.08),
              ]
            : [
                primary.withValues(alpha: 0.12),
                secondary.withValues(alpha: 0.04),
              ],
      );

  // ─── Radii ───────────────────────────────────────────────────────────────
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0; // Buttons, Inputs, Chips
  static const double radiusLarge = 12.0; // Cards, Panels, Modals
  static const double radiusXL = 20.0; // Hero Cards, Onboarding Dialogs
  static const double radiusFull = 9999.0; // Avatars, Pills

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        tertiary: tertiary,
        surface: surfaceDark,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDarkPrimary,
        onError: Colors.white,
      ),
      textTheme: _buildTextTheme(
        headlineColor: textDarkPrimary,
        bodyColor: textDarkPrimary,
        secondaryColor: textDarkSecondary,
        mutedColor: textDarkMuted,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textDarkPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        iconTheme: const IconThemeData(color: textDarkPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDarkAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
        hintStyle: GoogleFonts.dmSans(color: textDarkMuted, fontSize: 15),
        labelStyle: GoogleFonts.dmSans(color: textDarkSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        errorStyle: GoogleFonts.dmSans(color: danger, fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48), // CloudPulse Large Button (48px)
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          elevation: 0,
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.dmSans(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceDarkAlt,
        selectedColor: primary,
        secondarySelectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: const BorderSide(color: borderDark),
        ),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textDarkPrimary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primary,
        unselectedItemColor: textDarkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: borderDark,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceDarkAlt,
        contentTextStyle: GoogleFonts.dmSans(color: textDarkPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderDark),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Typography Builder ───────────────────────────────────────────────────
  // Headlines: Plus Jakarta Sans | Body: DM Sans | Mono: Roboto Mono
  static TextTheme _buildTextTheme({
    required Color headlineColor,
    required Color bodyColor,
    required Color secondaryColor,
    required Color mutedColor,
  }) {
    return TextTheme(
      // Display: Plus Jakarta Sans 52px extra-bold
      displayLarge: GoogleFonts.plusJakartaSans(
        color: headlineColor,
        fontWeight: FontWeight.w800,
        fontSize: 32,
        letterSpacing: 0.025,
      ),
      // Headline: Plus Jakarta Sans 40px bold
      headlineLarge: GoogleFonts.plusJakartaSans(
        color: headlineColor,
        fontWeight: FontWeight.w700,
        fontSize: 26,
        letterSpacing: 0.015,
      ),
      // Subhead: Plus Jakarta Sans 28px semibold
      headlineMedium: GoogleFonts.plusJakartaSans(
        color: headlineColor,
        fontWeight: FontWeight.w600,
        fontSize: 22,
        letterSpacing: 0.01,
      ),
      // Title: Plus Jakarta Sans 18px semibold
      titleLarge: GoogleFonts.plusJakartaSans(
        color: headlineColor,
        fontWeight: FontWeight.w600,
        fontSize: 17,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        color: headlineColor,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      // Body Large: DM Sans 18px regular
      bodyLarge: GoogleFonts.dmSans(
        color: bodyColor,
        fontSize: 16,
        height: 1.5,
      ),
      // Body: DM Sans 16px regular
      bodyMedium: GoogleFonts.dmSans(
        color: secondaryColor,
        fontSize: 14,
        height: 1.5,
      ),
      // Body Small: DM Sans 14px regular
      bodySmall: GoogleFonts.dmSans(
        color: mutedColor,
        fontSize: 12,
        height: 1.4,
      ),
      // Labels / Controls: DM Sans 14px 600
      labelLarge: GoogleFonts.dmSans(
        color: headlineColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      labelMedium: GoogleFonts.dmSans(
        color: secondaryColor,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  /// Roboto Mono text style for financial numbers and monetary amounts
  static TextStyle monoCurrency({
    Color color = textDarkPrimary,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.robotoMono(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: -0.2,
    );
  }
}
