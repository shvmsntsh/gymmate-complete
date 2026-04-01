import 'package:flutter/material.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData buildLightTheme({
    Color primary = AppColors.accentBrand,
    Color secondary = AppColors.accentSoft,
  }) {
    const scheme = ColorScheme.light(
      primary: AppColors.accentBrand,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.accentSoft,
      onSecondary: AppColors.lightTextPrimary,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutline,
      shadow: Color(0x14000000),
      scrim: Color(0x44000000),
    );

    return _buildTheme(
      brightness: Brightness.light,
      scheme: scheme.copyWith(primary: primary, secondary: secondary),
      scaffold: AppColors.lightBackground,
      surfaceLow: AppColors.lightSurfaceLow,
      surfaceHigh: AppColors.lightSurfaceHigh,
      surfaceHighest: AppColors.lightSurfaceHighest,
      textPrimary: AppColors.lightTextPrimary,
      textSecondary: AppColors.lightTextSecondary,
      primary: primary,
    );
  }

  static ThemeData buildDarkTheme({
    Color primary = AppColors.accentSoft,
    Color secondary = AppColors.accentStrong,
  }) {
    const scheme = ColorScheme.dark(
      primary: AppColors.accentSoft,
      onPrimary: AppColors.textOnAccent,
      secondary: AppColors.accentStrong,
      onSecondary: AppColors.textOnAccent,
      error: AppColors.error,
      onError: Color(0xFF690005),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutline,
      shadow: Colors.black54,
      scrim: Color(0x99000000),
    );

    return _buildTheme(
      brightness: Brightness.dark,
      scheme: scheme.copyWith(primary: primary, secondary: secondary),
      scaffold: AppColors.darkBackground,
      surfaceLow: AppColors.darkSurfaceLow,
      surfaceHigh: AppColors.darkSurfaceHigh,
      surfaceHighest: AppColors.darkSurfaceHighest,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      primary: primary,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
    required Color surfaceLow,
    required Color surfaceHigh,
    required Color surfaceHighest,
    required Color textPrimary,
    required Color textSecondary,
    required Color primary,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final bodyTheme = GoogleFonts.interTextTheme(base.textTheme);
    final headline = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      primaryColor: primary,
      canvasColor: scaffold,
      cardColor: surfaceHigh,
      dividerColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.22),
        selectionHandleColor: scheme.primary,
      ),
      textTheme: bodyTheme.copyWith(
        displayLarge: headline.displayLarge?.copyWith(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: -2.1,
          color: textPrimary,
        ),
        displayMedium: headline.displayMedium?.copyWith(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.6,
          color: textPrimary,
        ),
        headlineLarge: headline.headlineLarge?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          color: textPrimary,
        ),
        headlineMedium: headline.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          color: textPrimary,
        ),
        headlineSmall: headline.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: textPrimary,
        ),
        titleLarge: headline.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: textPrimary,
        ),
        titleMedium: headline.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary,
        ),
        titleSmall: headline.titleSmall?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: bodyTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.45,
          color: textPrimary,
        ),
        bodyMedium: bodyTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
          color: textSecondary,
        ),
        bodySmall: bodyTheme.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          color: textSecondary.withOpacity(0.9),
        ),
        labelLarge: bodyTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: textPrimary,
        ),
        labelMedium: bodyTheme.labelMedium?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: textSecondary,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scaffold,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(58),
          backgroundColor: Colors.transparent,
          foregroundColor: scheme.onPrimary,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: textPrimary,
          side: BorderSide(color: scheme.outline.withOpacity(0.42), width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: textPrimary, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        hintStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.inter(
          color: textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: scheme.error,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.outline.withOpacity(0.18),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.outline.withOpacity(0.12),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.primary.withOpacity(0.28),
            width: 1.2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.error.withOpacity(0.4),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: scheme.error.withOpacity(0.6),
            width: 1.2,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaceHighest,
        circularTrackColor: surfaceHighest,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHighest,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [
        AppSurfaceTheme(
          backgroundAlt: brightness == Brightness.dark
              ? AppColors.darkBackgroundAlt
              : AppColors.lightBackgroundAlt,
          surfaceLow: surfaceLow,
          surfaceHigh: surfaceHigh,
          surfaceHighest: surfaceHighest,
          accentWarm: AppColors.accentWarm,
        ),
      ],
    );
  }

  static final ThemeData lightTheme = buildLightTheme();
  static final ThemeData darkTheme = buildDarkTheme();
}

@immutable
class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  final Color backgroundAlt;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color accentWarm;

  const AppSurfaceTheme({
    required this.backgroundAlt,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.accentWarm,
  });

  @override
  AppSurfaceTheme copyWith({
    Color? backgroundAlt,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? accentWarm,
  }) {
    return AppSurfaceTheme(
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      accentWarm: accentWarm ?? this.accentWarm,
    );
  }

  @override
  AppSurfaceTheme lerp(ThemeExtension<AppSurfaceTheme>? other, double t) {
    if (other is! AppSurfaceTheme) {
      return this;
    }
    return AppSurfaceTheme(
      backgroundAlt: Color.lerp(backgroundAlt, other.backgroundAlt, t)!,
      surfaceLow: Color.lerp(surfaceLow, other.surfaceLow, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      accentWarm: Color.lerp(accentWarm, other.accentWarm, t)!,
    );
  }
}
