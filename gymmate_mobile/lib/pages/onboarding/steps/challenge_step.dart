import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';

class ChallengeStep extends StatelessWidget {
  final VoidCallback onNext;

  const ChallengeStep({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const title = 'Choose Your Challenges';
    const description = 'Select challenges to kickstart your journey';

    final challenges = [
      {'icon': Icons.local_fire_department, 'label': '7-Day Kickstart', 'value': '7_day_checkin', 'desc': 'Complete daily workouts for a week'},
      {'icon': Icons.timer, 'label': 'First Workout', 'value': 'first_workout', 'desc': 'Complete your first tracked workout session'},
      {'icon': Icons.group, 'label': 'Profile Photo', 'value': 'profile_photo', 'desc': 'Add a photo and a bio to your profile'},
      {'icon': Icons.track_changes, 'label': 'Goal Setting', 'value': 'goal_setting', 'desc': 'Set your first fitness goal'},
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selectedChallenge = provider.firstChallenge['type'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: ListView(
                children: challenges.map((challenge) => _buildChallengeCard(
                  context,
                  icon: challenge['icon'] as IconData,
                  title: challenge['label'] as String,
                  description: challenge['desc'] as String,
                  isSelected: selectedChallenge == challenge['value'],
                  onSelect: () {
                    provider.setFirstChallenge({'type': challenge['value']});
                  },
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  if (provider.firstChallenge['type'] == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a challenge.')),
                    );
                    return;
                  }
                  onNext();
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChallengeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}