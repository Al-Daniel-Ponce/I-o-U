// ignore_for_file: prefer_const_constructors, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/debt.dart';

/// Centralises all design tokens and theme configuration.
///
/// OOP principle: Encapsulation — callers reference named constants instead
/// of raw hex values. Both [darkTheme] and [lightTheme] are exposed so
/// [ThemeController] can switch between them at runtime.
class AppTheme {
  AppTheme._();

  // ── Shared brand colours (same in both themes) ────────────────────────────
  static const Color primary      = Color(0xFF0D7377);
  static const Color primaryDark  = Color(0xFF0A5C60);
  static const Color primaryLight = Color(0xFF14AFAB);
  static const Color accent       = Color(0xFFFFB347);
  static const Color accentDark   = Color(0xFFE8952A);

  static const Color success      = Color(0xFF4CAF87);
  static const Color warning      = Color(0xFFFFB347);
  static const Color error        = Color(0xFFE57373);

  static const Color unpaidColor  = Color(0xFFE57373);
  static const Color partialColor = Color(0xFFFFB347);
  static const Color paidColor    = Color(0xFF4CAF87);

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0E1E20);
  static const Color surface      = Color(0xFF162527);
  static const Color surfaceLight = Color(0xFF1E3335);
  static const Color cardBg       = Color(0xFF1A2E30);
  static const Color textPrimary   = Color(0xFFF0F7F7);
  static const Color textSecondary = Color(0xFF8AACAE);
  static const Color textMuted     = Color(0xFF5A8080);

  // ── Light palette ─────────────────────────────────────────────────────────
  static const Color lBackground   = Color(0xFFF0F7F7);
  static const Color lSurface      = Color(0xFFFFFFFF);
  static const Color lSurfaceLight = Color(0xFFE8F4F4);
  static const Color lCardBg       = Color(0xFFFFFFFF);
  static const Color lTextPrimary   = Color(0xFF0E1E20);
  static const Color lTextSecondary = Color(0xFF3A6B6E);
  static const Color lTextMuted     = Color(0xFF7AACAE);

  // ── Status → Color ────────────────────────────────────────────────────────
  static Color statusColor(DebtStatus status) {
    switch (status) {
      case DebtStatus.paid:    return paidColor;
      case DebtStatus.partial: return partialColor;
      case DebtStatus.unpaid:  return unpaidColor;
    }
  }

  // ── Shared input decoration factory ──────────────────────────────────────
  static InputDecorationTheme _inputTheme(Color fill, Color border, Color label, Color hint) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error, width: 2),
      ),
      labelStyle: TextStyle(color: label),
      hintStyle:  TextStyle(color: hint),
    );
  }

  // ── Dark theme ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(TextTheme(
        displayLarge:  const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        displayMedium: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge:    const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium:   const TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     const TextStyle(color: textPrimary),
        bodyMedium:    const TextStyle(color: textSecondary),
        labelLarge:    const TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
            color: textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: surface),
      elevatedButtonTheme: _elevatedBtn(),
      inputDecorationTheme: _inputTheme(
        surfaceLight,
        textMuted.withOpacity(0.3),
        textSecondary,
        textMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: GoogleFonts.dmSans(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerColor: textMuted.withOpacity(0.2),
    );
  }

  // ── Light theme ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lBackground,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: lSurface,
        error: error,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(TextTheme(
        displayLarge:  const TextStyle(color: lTextPrimary, fontWeight: FontWeight.w700),
        displayMedium: const TextStyle(color: lTextPrimary, fontWeight: FontWeight.w700),
        titleLarge:    const TextStyle(color: lTextPrimary, fontWeight: FontWeight.w600),
        titleMedium:   const TextStyle(color: lTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     const TextStyle(color: lTextPrimary),
        bodyMedium:    const TextStyle(color: lTextSecondary),
        labelLarge:    const TextStyle(color: lTextPrimary, fontWeight: FontWeight.w600),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: lBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
            color: lTextPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: lTextPrimary),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: lSurface),
      elevatedButtonTheme: _elevatedBtn(),
      inputDecorationTheme: _inputTheme(
        lSurfaceLight,
        lTextMuted.withOpacity(0.4),
        lTextSecondary,
        lTextMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lSurfaceLight,
        contentTextStyle: GoogleFonts.dmSans(color: lTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      cardColor: lCardBg,
      dividerColor: lTextMuted.withOpacity(0.2),
    );
  }

  static ElevatedButtonThemeData _elevatedBtn() => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 15),
    ),
  );
}