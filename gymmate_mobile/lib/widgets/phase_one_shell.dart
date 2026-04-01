import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/themes/app_theme.dart';
import 'package:gymmate_mobile/widgets/animated_background.dart';
import 'package:gymmate_mobile/widgets/brand_logo.dart';
import 'package:google_fonts/google_fonts.dart';

class PhaseOneScaffold extends StatelessWidget {
  final Widget child;
  final bool lightweightBackground;
  final bool denserGlow;
  final bool scrollable;

  const PhaseOneScaffold({
    super.key,
    required this.child,
    this.lightweightBackground = false,
    this.denserGlow = false,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(
            denserGlow: denserGlow,
            lightweight: lightweightBackground,
          ),
          SafeArea(
            child: scrollable
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: child,
                        ),
                      );
                    },
                  )
                : child,
          ),
        ],
      ),
    );
  }
}

class PhaseOnePageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final CrossAxisAlignment crossAxisAlignment;

  const PhaseOnePageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        final frame = Padding(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: [child],
            ),
          ),
        );

        return Align(
          alignment: Alignment.topCenter,
          child: viewport.hasBoundedHeight
              ? ConstrainedBox(
                  constraints: BoxConstraints(minHeight: viewport.maxHeight),
                  child: frame,
                )
              : frame,
        );
      },
    );
  }
}

class PhaseOneTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PhaseOneTopBar({
    super.key,
    this.onBack,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaceTheme>();

    return Row(
      children: [
        if (onBack != null)
          _TopPillButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack!)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: (surfaces?.surfaceHigh ?? theme.colorScheme.surface)
                  .withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const BrandLogo(),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GymMate',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your Fitness HQ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Spacer(),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _TopPillButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopPillButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaceTheme>();
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (surfaces?.surfaceHigh ?? theme.colorScheme.surface)
              .withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.16),
          ),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class PhaseOneSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const PhaseOneSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaceTheme>();
    final surface = surfaces?.surfaceHigh ?? theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.22 : 0.14,
    );

    return Container(
      decoration: BoxDecoration(
        color: surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.88 : 0.92,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.06,
            ),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(22),
        child: child,
      ),
    );
  }
}

class PhaseOneBadge extends StatelessWidget {
  final String label;

  const PhaseOneBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          color: AppColors.textOnAccent,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    ).animate().fadeIn(duration: 280.ms);
  }
}

class PhaseOneStatusBanner extends StatelessWidget {
  final String message;
  final bool isError;

  const PhaseOneStatusBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

class PhaseOnePrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData trailingIcon;

  const PhaseOnePrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: loading ? null : onTap,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient(),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.26),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: AppColors.textOnAccent.withValues(alpha: 0.95),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.textOnAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(trailingIcon, color: AppColors.textOnAccent),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class PhaseOneSectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const PhaseOneSectionTitle({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: GoogleFonts.inter(
            color: theme.colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(title, style: theme.textTheme.displayMedium),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}

class PhaseOneFooterNote extends StatelessWidget {
  final String label;

  const PhaseOneFooterNote({super.key, this.label = 'Powered by GymMate'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.52),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
