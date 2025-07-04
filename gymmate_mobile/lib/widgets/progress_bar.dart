import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  const AnimatedProgressBar({Key? key, required this.progress}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 10,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
          ).animate().slideX(begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeInOut),
        ),
      ),
    );
  }
} 