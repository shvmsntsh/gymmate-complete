import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/widgets/animated_background.dart';
import 'package:gymmate_mobile/widgets/brand_loader.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              widget.nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const BrandedLoadingScreen(
      title: 'GymMate',
      subtitle: 'Your Fitness HQ',
      showTagline: true,
    );
  }
}

class BrandedLoadingScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showTagline;
  final bool lightweight;

  const BrandedLoadingScreen({
    super.key,
    required this.title,
    required this.subtitle,
    this.showTagline = false,
    this.lightweight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBackground(denserGlow: true, lightweight: lightweight),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandLoader(
                    size: showTagline ? 164 : 144,
                    label: subtitle.toUpperCase(),
                    compact: lightweight,
                  ),
                  const SizedBox(height: 24),
                  Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.8,
                          color: theme.colorScheme.onSurface,
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 650.ms)
                      .slideY(begin: 0.15, curve: Curves.easeOutCubic),
                  const SizedBox(height: 10),
                  Text(
                        showTagline ? 'Your Fitness HQ' : subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(delay: 260.ms, duration: 650.ms)
                      .slideY(begin: 0.18, curve: Curves.easeOutCubic),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
