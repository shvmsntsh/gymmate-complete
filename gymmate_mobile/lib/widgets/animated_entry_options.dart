import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnimatedEntryOptions extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onJoin;
  const AnimatedEntryOptions({Key? key, required this.onLogin, required this.onJoin}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Text(
          '',
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, duration: 500.ms),
        const SizedBox(height: 32),
        Image.asset(
          'assets/illustration.png',
          height: 200,
          fit: BoxFit.contain,
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0, duration: 500.ms),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              _AnimatedEntryButton(
                label: 'Login',
                onTap: onLogin,
                color: const Color(0xFFF8D84B),
                textColor: const Color(0xFF1B150B),
                delay: 200,
              ),
              const SizedBox(height: 24),
              _AnimatedEntryButton(
                label: 'Join Now',
                onTap: onJoin,
                color: Colors.transparent,
                textColor: const Color(0xFFD4A62A),
                border: Border.all(color: const Color(0xFFD4A62A), width: 2),
                delay: 300,
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class _AnimatedEntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;
  final Border? border;
  final int delay;
  const _AnimatedEntryButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
    this.border,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: delay.ms)
        .scaleXY(begin: 0.8, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
} 