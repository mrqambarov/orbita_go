import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrbitaColors {
  // Brand
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF4B44CC);
  static const Color primaryLight = Color(0xFF9B95FF);
  static const Color accent = Color(0xFFFFD700);

  // Background
  static const Color background = Color(0xFF0A0A14);
  static const Color surface = Color(0xFF13131F);
  static const Color surfaceLight = Color(0xFF1C1C2E);
  static const Color card = Color(0xFF1A1A2E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF6B6B8A);

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFFF5252);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4B44CC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0A0A14), Color(0xFF13131F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class OrbitaTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: OrbitaColors.background,
      colorScheme: const ColorScheme.dark(
        primary: OrbitaColors.primary,
        secondary: OrbitaColors.accent,
        surface: OrbitaColors.surface,
        error: OrbitaColors.error,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
        displayMedium: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.nunito(
          color: OrbitaColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: GoogleFonts.nunito(
          color: OrbitaColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: OrbitaColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OrbitaColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: OrbitaColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.nunito(
          color: OrbitaColors.textHint,
          fontSize: 15,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: OrbitaColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: OrbitaColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF2A2A3E)),
        ),
      ),
    );
  }
}
