import 'package:flutter/material.dart';

class AppTheme {
  static const forest = Color(0xFF163D34);
  static const green = Color(0xFF317561);
  static const background = Color(0xFFF7F8F3);
  static const ink = Color(0xFF172B28);
  static const muted = Color(0xFF6D8075);
  static const coral = Color(0xFFE9A47C);
  static const paleGreen = Color(0xFFE8F2EB);
  static const border = Color(0xFFE3EBE4);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: green, primary: forest, secondary: green,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: Typography.material2021().black.apply(
        bodyColor: ink, displayColor: ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background, foregroundColor: ink,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleTextStyle: TextStyle(color: ink, fontSize: 21, fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white, indicatorColor: paleGreen,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: forest, foregroundColor: Colors.white,
      ),
    );
  }
}
