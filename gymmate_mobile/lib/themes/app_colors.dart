import 'package:flutter/material.dart';

/// Central place for all brand colours used in GymMate.
/// By keeping colours in one class we can change branding consistently
/// across the whole code-base from a single location.
class AppColors {
  /// Primary accent colour used for call-to-action buttons, highlights etc.
  static const Color accentYellow = Color(0xFFF8D84B);

  /// A slightly darker gold used mainly for borders on dark backgrounds.
  static const Color accentDarkGold = Color(0xFFD4A62A);

  /// Text colour that sits on top of the accent yellow buttons (dark brown/blackish)
  static const Color textOnAccent = Color(0xFF1B150B);

  // Existing palette reference colours (kept for convenience)
  static const Color darkBackground = Color(0xFF232014);
  static const Color lightCream = Color(0xFFFCFAF6);
} 