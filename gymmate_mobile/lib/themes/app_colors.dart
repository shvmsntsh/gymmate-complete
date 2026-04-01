import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color accentSoft = Color(0xFFFFB59D);
  static const Color accentBrand = Color(0xFFFF5200);
  static const Color accentStrong = Color(0xFFFF5711);
  static const Color accentWarm = Color(0xFFE5BEB2);

  static const Color darkBackground = Color(0xFF131314);
  static const Color darkBackgroundAlt = Color(0xFF0E0E0F);
  static const Color darkSurfaceLow = Color(0xFF1C1B1C);
  static const Color darkSurface = Color(0xFF201F20);
  static const Color darkSurfaceHigh = Color(0xFF2A2A2B);
  static const Color darkSurfaceHighest = Color(0xFF353436);
  static const Color darkOutline = Color(0xFF5C4037);
  static const Color darkTextPrimary = Color(0xFFE5E2E3);
  static const Color darkTextSecondary = Color(0xFFC8C6C8);
  static const Color darkTextMuted = Color(0xFF909193);

  static const Color lightBackground = Color(0xFFFDF8F6);
  static const Color lightBackgroundAlt = Color(0xFFFBFAFB);
  static const Color lightSurfaceLow = Color(0xFFF4F0EF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF0EDEB);
  static const Color lightSurfaceHighest = Color(0xFFEAE3E0);
  static const Color lightOutline = Color(0xFFE7D9D4);
  static const Color lightTextPrimary = Color(0xFF2C2C2E);
  static const Color lightTextSecondary = Color(0xFF5E5E61);

  static const Color success = Color(0xFF82D5A3);
  static const Color error = Color(0xFFFFB4AB);
  static const Color textOnAccent = Color(0xFF390C00);

  // Compatibility aliases for the existing codebase while screens are migrated.
  static const Color accentYellow = accentSoft;
  static const Color accentDarkGold = accentStrong;
  static const Color lightCream = lightBackground;

  static const List<Color> ctaGradient = [accentSoft, accentStrong];
  static const List<Color> brandGlow = [accentStrong, accentBrand];

  static LinearGradient primaryGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: ctaGradient,
    );
  }
}
