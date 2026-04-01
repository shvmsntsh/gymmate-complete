import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';

class EditorialBackdrop extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool safeTop;
  final bool safeBottom;

  const EditorialBackdrop({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 120),
    this.safeTop = true,
    this.safeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.scaffoldBackgroundColor,
            isDark ? AppColors.darkBackgroundAlt : AppColors.lightBackgroundAlt,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: _GlowOrb(
              size: 240,
              color: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.18 : 0.12,
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -20,
            child: _GlowOrb(
              size: 180,
              color: AppColors.accentSoft.withValues(
                alpha: isDark ? 0.10 : 0.12,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: 40,
            child: _GlowOrb(
              size: 200,
              color: AppColors.accentStrong.withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
            ),
          ),
          SafeArea(top: safeTop, bottom: safeBottom, child: content),
        ],
      ),
    );
  }
}

class EditorialSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const EditorialSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = 30,
    this.color,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            color ??
            theme.colorScheme.surface.withValues(alpha: isDark ? 0.94 : 0.98),
        borderRadius: BorderRadius.circular(radius),
        border:
            border ??
            Border.all(
              color: theme.colorScheme.outline.withValues(
                alpha: isDark ? 0.24 : 0.54,
              ),
            ),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class EditorialKicker extends StatelessWidget {
  final String label;

  const EditorialKicker(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: AppColors.textOnAccent,
        ),
      ),
    );
  }
}

class EditorialMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const EditorialMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = iconColor ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 18),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class EditorialPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final bool loading;

  const EditorialPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailing,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentStrong.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textOnAccent,
                ),
              )
            else
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textOnAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (!loading && trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class EditorialSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const EditorialSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
        backgroundColor: theme.colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      ),
      child: Text(label),
    );
  }
}

class EditorialProgressRing extends StatelessWidget {
  final double progress;
  final String value;
  final String label;
  final String sublabel;
  final double size;

  const EditorialProgressRing({
    super.key,
    required this.progress,
    required this.value,
    required this.label,
    required this.sublabel,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 14,
              backgroundColor: Colors.transparent,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: ShaderMask(
              shaderCallback: (rect) =>
                  AppColors.primaryGradient().createShader(rect),
              child: CircularProgressIndicator(
                value: clamped,
                strokeWidth: 14,
                strokeCap: StrokeCap.round,
                backgroundColor: Colors.transparent,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                sublabel,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EditorialSectionHeading extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const EditorialSectionHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(subtitle!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class EditorialBlurImage extends StatelessWidget {
  final Widget child;
  final double height;
  final BorderRadius borderRadius;

  const EditorialBlurImage({
    super.key,
    required this.child,
    this.height = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(30)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: borderRadius,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHigh,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
              child: const SizedBox.expand(),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
