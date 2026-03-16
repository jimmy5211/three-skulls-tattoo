import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlack = Color(0xFF000000);
  static const Color deepBlack = Color(0xFF1A1A1A);
  static const Color surfaceColor = Color(0xFF242424);
  static const Color cardColor = Color(0xFF2E2E2E);
  static const Color borderColor = Color(0xFF3D3D3D);
  static const Color accentRed = Color(0xFFC0392B);
  static const Color accentRedDark = Color(0xFF8B0000);
  static const Color accentRedBright = Color(0xFFE74C3C);
  static const Color textWhite = Color(0xFFF0F0F0);
  static const Color textGrey = Color(0xFFA0A0A0);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accentRed,
        secondary: accentRedDark,
        surface: surfaceColor,
        onPrimary: textWhite,
        onSecondary: textWhite,
        onSurface: textWhite,
        error: accentRedBright,
      ),
      scaffoldBackgroundColor: primaryBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBlack,
        foregroundColor: textWhite,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'BlackOpsOne',
          fontSize: 20,
          color: textWhite,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentRed,
          foregroundColor: textWhite,
          elevation: 4,
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'BlackOpsOne',
          fontSize: 32,
          color: textWhite,
          letterSpacing: 3,
        ),
        displayMedium: TextStyle(
          fontFamily: 'BlackOpsOne',
          fontSize: 24,
          color: textWhite,
          letterSpacing: 2,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Raleway',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textWhite,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Raleway',
          fontSize: 16,
          color: textWhite,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Raleway',
          fontSize: 14,
          color: textGrey,
        ),
      ),
      iconTheme: const IconThemeData(
        color: textWhite,
        size: 24,
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
      ),
    );
  }
}
