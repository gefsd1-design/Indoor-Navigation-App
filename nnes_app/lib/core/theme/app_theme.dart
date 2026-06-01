import 'package:flutter/material.dart';

class AppTheme {
  // NNES Design Palette
  static const Color background = Color(0xFF131313);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainerHighest = Color(0xFF353534);
  
  static const Color primaryContainer = Color(0xFF961D21);
  static const Color primary = Color(0xFFFFB3AE);
  static const Color onPrimaryContainer = Color(0xFFFFA8A2);
  static const Color onPrimaryFixedVariant = Color(0xFF8C151B);
  
  static const Color secondary = Color(0xFFDCC398);
  static const Color secondaryContainer = Color(0xFF584725);
  static const Color onSecondaryContainer = Color(0xFFCDB58B);
  
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFE0BFBC);
  static const Color outlineVariant = Color(0xFF59413F);

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryContainer,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Manrope', color: onSurface, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontFamily: 'Manrope', color: onSurface, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontFamily: 'Manrope', color: onSurface, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: 'Manrope', color: onSurface, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: onSurface),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: onSurfaceVariant),
        labelLarge: TextStyle(fontFamily: 'Inter', color: onSurface, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLow,
        elevation: 0, // Tonal layering instead of shadows
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // xl roundedness
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimaryContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // DEFAULT (0.25rem)
          elevation: 0,
        ),
      ),
    );
  }
}
