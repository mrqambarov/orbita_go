import 'package:flutter/material.dart';

class GamesTheme {
  static const Color background = Color(0xFF070714);
  static const Color card = Color(0xFF0F0F28);
  static const Color primary = Color(0xFF00E5FF); // Neon Cyan
  static const Color secondary = Color(0xFFE040FB); // Neon Magenta
  static const Color accent = Color(0xFFFFD700); // Neon Gold
  static const Color text = Colors.white;
  static const Color textSecondary = Color(0xFF8F8FA8);
  static const Color success = Color(0xFF00E676);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: card,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF141432),
      hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
      labelStyle: const TextStyle(color: primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}
