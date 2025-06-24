import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
import '../../../providers/onboarding_provider.dart';

class CompletionStep extends StatefulWidget {
  const CompletionStep({Key? key}) : super(key: key);

  @override
  State<CompletionStep> createState() => _CompletionStepState();
}

class _CompletionStepState extends State<CompletionStep> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _startCelebration();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _startCelebration() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  void _completeOnboarding() async {
    final provider = context.read<OnboardingProvider>();
    await provider.completeOnboarding();
    
    // After completion, navigate to home page
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('CompletionStep build called');
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple
              ],
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildCelebrationContent(context, provider),
                const SizedBox(height: 32),
                _buildNextSteps(context),
                const SizedBox(height: 40),
                _buildGetStartedButton(context),
                const SizedBox(height: 20),
              ].animate(interval: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          '🎉 Welcome to GymMate! 🎉',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Your fitness journey starts now.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCelebrationContent(BuildContext context, OnboardingProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.emoji_events_rounded,
          size: 80,
          color: colorScheme.primary,
        ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(
          'Congratulations!',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'You\'ve completed onboarding and earned your first rewards!',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context, 'XP Earned', provider.totalXP.toString(), Icons.star_rounded),
              _buildStatItem(context, 'Level', provider.level.toString(), Icons.shield_rounded),
              _buildStatItem(context, 'Badges', provider.badges.length.toString(), Icons.verified_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNextSteps(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What\'s Next?',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildNextStepItem(context, 'Complete Your First Workout', 'Start with a beginner-friendly routine.', Icons.fitness_center_rounded),
        const SizedBox(height: 12),
        _buildNextStepItem(context, 'Explore Challenges', 'Join a challenge to earn more rewards.', Icons.military_tech_rounded),
        const SizedBox(height: 12),
        _buildNextStepItem(context, 'Log Your First Meal', 'Keep track of your nutrition.', Icons.restaurant_menu_rounded),
      ],
    );
  }

  Widget _buildNextStepItem(BuildContext context, String title, String subtitle, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.secondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _completeOnboarding,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text('Go to Dashboard'),
    );
  }
}