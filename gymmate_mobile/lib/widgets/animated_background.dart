import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/themes/app_theme.dart';

class AnimatedBackground extends StatelessWidget {
  final bool showGrid;
  final bool denserGlow;
  final bool lightweight;

  const AnimatedBackground({
    super.key,
    this.showGrid = true,
    this.denserGlow = false,
    this.lightweight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaceTheme>();
    final reduceEffects = lightweight || kIsWeb;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              surfaces?.backgroundAlt ?? theme.scaffoldBackgroundColor,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            if (showGrid && !reduceEffects)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DotGridPainter(
                      color: theme.colorScheme.onSurface.withOpacity(
                        theme.brightness == Brightness.dark ? 0.07 : 0.04,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: -40,
              left: -30,
              child: _AnimatedOrb(
                size: denserGlow ? 250 : 220,
                color: AppColors.accentStrong.withOpacity(0.24),
                duration: 4200.ms,
                offset: const Offset(14, 18),
                animate: !reduceEffects,
              ),
            ),
            Positioned(
              top: 120,
              right: -70,
              child: _AnimatedOrb(
                size: denserGlow ? 280 : 220,
                color: AppColors.accentSoft.withOpacity(0.20),
                duration: 5200.ms,
                offset: const Offset(-18, 10),
                animate: !reduceEffects,
              ),
            ),
            Positioned(
              bottom: -90,
              left: 40,
              child: _AnimatedOrb(
                size: denserGlow ? 260 : 210,
                color: theme.colorScheme.primary.withOpacity(0.16),
                duration: 4700.ms,
                offset: const Offset(18, -12),
                animate: !reduceEffects,
              ),
            ),
            if (!reduceEffects)
              Positioned(
                bottom: 140,
                right: 20,
                child: _AccentLine(
                  color: AppColors.accentWarm.withOpacity(0.16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedOrb extends StatelessWidget {
  final double size;
  final Color color;
  final Duration duration;
  final Offset offset;
  final bool animate;

  const _AnimatedOrb({
    required this.size,
    required this.color,
    required this.duration,
    required this.offset,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: animate ? 90 : 54,
            spreadRadius: animate ? 18 : 8,
          ),
        ],
      ),
    );

    if (!animate) {
      return orb;
    }

    return orb
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .move(
          begin: Offset.zero,
          end: offset,
          duration: duration,
          curve: Curves.easeInOut,
        )
        .fade(begin: 0.55, end: 1, duration: duration);
  }
}

class _AccentLine extends StatelessWidget {
  final Color color;

  const _AccentLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: color, width: 1),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(begin: 0.94, end: 1.02, duration: 3600.ms);
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;

  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 24.0;
    final paint = Paint()..color = color;

    for (double x = 10; x < size.width; x += gap) {
      for (double y = 10; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
