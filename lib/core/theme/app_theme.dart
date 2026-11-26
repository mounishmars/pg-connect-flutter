import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF123B67);
  static const blue = Color(0xFF246BCE);
  static const background = Color(0xFFF5F7FB);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: navy),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Color(0xFF172B4D),
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3E9F2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
  );
}
