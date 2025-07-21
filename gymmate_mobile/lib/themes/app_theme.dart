import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static const Color _lightCream = Color(0xFFFCFAF6);
  static const Color _lightGold = Color(0xFFB59F5B);
  static const Color _lightYellow = AppColors.accentYellow;
  static const Color _lightInput = Color(0xF7F4EDFF);

  static const Color _darkBrown = Color(0xFF232014);
  static const Color _darkInput = Color(0xFF3A3320);
  static const Color _darkGold = Color(0xFFB59F5B);
  static const Color _darkYellow = AppColors.accentYellow;

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _lightGold,
    scaffoldBackgroundColor: _lightCream,
    colorScheme: const ColorScheme.light(
      primary: _lightGold,
      secondary: AppColors.accentYellow,
      surface: Colors.white,
      onPrimary: Colors.black,
      onSurface: Colors.black87,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
        titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
        bodyLarge: TextStyle(fontSize: 18, color: _lightGold),
        bodyMedium: TextStyle(fontSize: 16, color: _lightGold),
        bodySmall: TextStyle(fontSize: 14, color: _lightGold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _lightInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _lightGold, width: 2),
      ),
      hintStyle: const TextStyle(color: _lightGold),
      labelStyle: const TextStyle(color: _lightGold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentYellow,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _lightGold,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, decoration: TextDecoration.underline),
      ),
    ),
    iconTheme: const IconThemeData(color: _lightGold),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _darkGold,
    scaffoldBackgroundColor: _darkBrown,
    colorScheme: const ColorScheme.dark(
      primary: _darkGold,
      secondary: AppColors.accentYellow,
      surface: _darkBrown,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 18, color: _darkGold),
        bodyMedium: TextStyle(fontSize: 16, color: _darkGold),
        bodySmall: TextStyle(fontSize: 14, color: _darkGold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkInput,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _darkGold, width: 2),
      ),
      hintStyle: const TextStyle(color: _darkGold),
      labelStyle: const TextStyle(color: _darkGold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentYellow,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _darkGold,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.normal, decoration: TextDecoration.underline),
      ),
    ),
    iconTheme: const IconThemeData(color: _darkGold),
  );
} 