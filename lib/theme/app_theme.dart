import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Light Theme Colors
  static const Color _lightSurface = Color(0xFFFCF9F8);
  static const Color _lightPrimary = Color(0xFF006C52);
  static const Color _lightPrimaryContainer = Color(0xFF98FFD9);
  static const Color _lightOnSurface = Color(0xFF1C1B1B);
  static const Color _lightError = Color(0xFFBA1A1A);

  // Dark Theme Colors
  static const Color _darkSurface = Color(0xFF121212);
  static const Color _darkPrimary = Color(0xFF8FF6D0);
  static const Color _darkPrimaryContainer = Color(0xFF00513D);
  static const Color _darkOnSurface = Color(0xFFE5E2E1);
  static const Color _darkError = Color(0xFFFFB4AB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        surface: _lightSurface,
        primary: _lightPrimary,
        primaryContainer: _lightPrimaryContainer,
        onSurface: _lightOnSurface,
        error: _lightError,
      ),
      scaffoldBackgroundColor: _lightSurface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: _lightOnSurface,
        displayColor: _lightOnSurface,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        surface: _darkSurface,
        primary: _darkPrimary,
        primaryContainer: _darkPrimaryContainer,
        onSurface: _darkOnSurface,
        error: _darkError,
      ),
      scaffoldBackgroundColor: _darkSurface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: _darkOnSurface,
        displayColor: _darkOnSurface,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 2,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: const Color(0xFF003829),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
