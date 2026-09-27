import 'package:flutter/material.dart';

class AppTheme {
  // SmartProcure brand colors
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color darkGreen = Color(0xFF12372A);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color softGreen = Color(0xFFF4FAF4);

  static const Color governmentBlue = Color(0xFF0B4F85);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color amberWarning = Color(0xFFFFA000);
  static const Color errorRed = Color(0xFFD32F2F);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    fontFamily: 'Roboto',

    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryGreen,
      onPrimary: Colors.white,
      secondary: governmentBlue,
      surface: Colors.white,
      error: errorRed,
    ),

    scaffoldBackgroundColor: const Color(0xFFF8FBF8),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: darkGreen,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: darkGreen,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: darkGreen,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: darkGreen,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: darkGreen,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: darkGreen,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: darkGreen,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: darkGreen,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: Color(0xFF33443B),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF52635A),
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Color(0xFF71847B),
      ),
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: softGreen,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: errorRed,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: errorRed,
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF8A9A91),
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF52635A),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: primaryGreen,
        side: const BorderSide(
          color: primaryGreen,
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: lightGreen,
      selectedColor: primaryGreen,
      labelStyle: const TextStyle(
        color: darkGreen,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: Color(0xFFE4EAE5),
      thickness: 1,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryGreen,
    ),
  );
}