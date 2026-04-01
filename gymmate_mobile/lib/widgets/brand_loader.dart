import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/widgets/brand_logo.dart';

class BrandLoader extends StatefulWidget {
  final double size;
  final String? label;
  final bool compact;

  const BrandLoader({
    super.key,
    this.size = 132,
    this.label,
    this.compact = false,
  });

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = widget.label;
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.88);
    const lightweight = kIsWeb;
    final pulseScale =
        0.97 + (math.sin(_controller.value * math.pi * 2) * 0.035);
    final shimmer = 0.5 + (math.sin(_controller.value * math.pi * 2) * 0.5);

    final logoCore = Container(
      width: widget.size * 0.52,
      height: widget.size * 0.52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.surface.withValues(alpha: 0.98),
                  theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.96,
                  ),
                ]
              : [
                  theme.colorScheme.surface.withValues(alpha: 0.98),
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.94,
                  ),
                ],
        ),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(
            alpha: isDark ? 0.06 : 0.04,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(
              alpha: isDark ? 0.16 : 0.12,
            ),
            blurRadius: lightweight ? 16 : (widget.compact ? 20 : 30),
            spreadRadius: lightweight ? 0 : 1,
          ),
          BoxShadow(
            color: AppColors.accentSoft.withValues(
              alpha: lightweight ? 0.06 : 0.08,
            ),
            blurRadius: lightweight ? 18 : 28,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: BrandLogo(width: widget.size * 0.44, height: widget.size * 0.44),
    );
    final animatedCore = Transform.scale(scale: pulseScale, child: logoCore);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              if (lightweight) {
                return CustomPaint(
                  painter: _MinimalLoaderPainter(
                    progress: _controller.value,
                    ringColor: theme.colorScheme.surfaceContainerHighest,
                    accentColor: theme.colorScheme.primary,
                    shimmer: shimmer,
                  ),
                  child: child,
                );
              }
              return CustomPaint(
                painter: _LoaderPainter(
                  progress: _controller.value,
                  baseColor: theme.colorScheme.surfaceContainerHighest,
                  glowColor: theme.colorScheme.primary,
                  shimmer: shimmer,
                ),
                child: child,
              );
            },
            child: Center(
              child: lightweight
                  ? animatedCore
                  : logoCore
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .scaleXY(
                          begin: 0.96,
                          end: 1.04,
                          duration: 1400.ms,
                          curve: Curves.easeInOut,
                        ),
            ),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: widget.compact ? 12 : 18),
          Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  letterSpacing: 1.1,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(begin: 0.35, end: 1, duration: 1100.ms),
        ],
      ],
    );
  }
}

class _MinimalLoaderPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color accentColor;
  final double shimmer;

  const _MinimalLoaderPainter({
    required this.progress,
    required this.ringColor,
    required this.accentColor,
    required this.shimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = ringColor.withValues(alpha: 0.55);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppColors.accentSoft.withValues(alpha: 0.06 + (shimmer * 0.05))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final accentRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          accentColor.withValues(alpha: 0.0),
          AppColors.accentSoft.withValues(alpha: 0.75),
          AppColors.accentStrong,
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.42, 0.68, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius - 8));

    final orbitAngle = (progress * math.pi * 2) - (math.pi / 2);
    final orbitOffset = Offset(
      center.dx + math.cos(orbitAngle) * (radius - 8),
      center.dy + math.sin(orbitAngle) * (radius - 8),
    );

    final orbitPaint = Paint()
      ..color = AppColors.accentSoft.withValues(alpha: 0.92)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawCircle(center, radius - 8, haloPaint);
    canvas.drawCircle(center, radius - 8, baseRing);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8),
      -math.pi / 2,
      math.pi * 1.35,
      false,
      accentRing,
    );
    canvas.drawCircle(orbitOffset, 4, orbitPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.shimmer != shimmer;
  }
}

class _LoaderPainter extends CustomPainter {
  final double progress;
  final Color baseColor;
  final Color glowColor;
  final double shimmer;

  const _LoaderPainter({
    required this.progress,
    required this.baseColor,
    required this.glowColor,
    required this.shimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final baseRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = baseColor.withValues(alpha: 0.9)
      ..strokeCap = StrokeCap.round;

    final glowRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          glowColor.withValues(alpha: 0.05),
          AppColors.accentSoft,
          AppColors.accentStrong,
          glowColor.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.38, 0.7, 1.0],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius - 6));

    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.accentSoft.withValues(alpha: 0.16 + (shimmer * 0.12));

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppColors.accentSoft.withValues(alpha: 0.04 + (shimmer * 0.05))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawCircle(center, radius - 10, haloPaint);
    canvas.drawCircle(center, radius - 6, pulsePaint);
    canvas.drawCircle(center, radius - 10, baseRing);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -math.pi / 2,
      math.pi * 1.55,
      false,
      glowRing,
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.shimmer != shimmer;
  }
}
