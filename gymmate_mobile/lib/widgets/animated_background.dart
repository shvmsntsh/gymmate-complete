import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Stack(
        children: [
          // Lottie animation (replace with your asset path)
          Lottie.asset(
            'assets/lottie/gym_bg.json',
            fit: BoxFit.cover,
            repeat: true,
            animate: true,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.background,
                    theme.colorScheme.surface.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 