import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({Key? key}) : super(key: key);

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep> {
  @override
  Widget build(BuildContext context) {
    // TODO: Implement your WelcomeStep UI here
    return Container();
  }

  Widget _buildHeader(BuildContext context, TextTheme textTheme) {
    return Column(
      children: [
        Icon(
          Icons.waving_hand_rounded,
          size: 60,
          color: Theme.of(context).primaryColor,
        ).animate().shake(delay: 500.ms, duration: 600.ms),
        const SizedBox(height: 24),
        Text(
          'Welcome to GymMate!',
          textAlign: TextAlign.center,
          style: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Your personal fitness journey starts right here. Let\'s get you set up.',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildFeatureCards(BuildContext context) {
    final features = [
      {
        'icon': Icons.track_changes_outlined,
        'title': 'Track Your Progress',
        'description': 'Monitor stats and see your gains over time.',
      },
      {
        'icon': Icons.emoji_events_outlined,
        'title': 'Earn Rewards',
        'description': 'Unlock badges and level up as you hit your goals.',
      },
      {
        'icon': Icons.people_outline_rounded,
        'title': 'Join a Community',
        'description': 'Connect with others and stay motivated together.',
      },
    ];

    return features.asMap().entries.map((entry) {
      final index = entry.key;
      final feature = entry.value;

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(feature['icon'] as IconData, color: Theme.of(context).primaryColor, size: 32),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature['title'].toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature['description'].toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (900 + index * 100).ms).slideX(begin: 0.5, curve: Curves.easeOutCubic);
    }).toList();
  }

  Widget _buildStartButton(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, child) {
        return ElevatedButton.icon(
          onPressed: provider.isLoading ? null : () => provider.nextStep(),
          icon: provider.isLoading
              ? Container()
              : const Icon(Icons.rocket_launch_outlined),
          label: provider.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                  ),
                )
              : const Text('Let\'s Go!'),
        ).animate().slideY(begin: 0.5, delay: 1400.ms, duration: 600.ms, curve: Curves.easeOutCubic);
      },
    );
  }
}