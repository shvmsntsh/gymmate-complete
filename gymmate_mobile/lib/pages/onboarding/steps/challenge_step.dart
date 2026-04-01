import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class ChallengeStep extends StatelessWidget {
  final VoidCallback onNext;

  const ChallengeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final challenges = [
      (
        icon: Icons.local_fire_department_rounded,
        title: '7-Day Kickstart',
        value: '7_day_checkin',
        description:
            'Show up for seven straight days and set your rhythm early.',
      ),
      (
        icon: Icons.timer_outlined,
        title: 'First Workout',
        value: 'first_workout',
        description:
            'Complete your first tracked session and lock in momentum.',
      ),
      (
        icon: Icons.emoji_events_outlined,
        title: 'Goal Setting',
        value: 'goal_setting',
        description: 'Make your first gym target real and visible on day one.',
      ),
      (
        icon: Icons.account_circle_outlined,
        title: 'Profile Finish',
        value: 'profile_photo',
        description:
            'Round out your profile and make your training space your own.',
      ),
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selectedType = provider.firstChallenge['type'] as String?;

        return OnboardingStepLayout(
          eyebrow: 'Challenge',
          title: 'Give your first week a clear target.',
          subtitle:
              'A starter challenge makes it easier to build early momentum instead of waiting for the perfect day.',
          body: Column(
            children: challenges
                .map(
                  (challenge) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingOptionCard(
                      title: challenge.title,
                      description: challenge.description,
                      icon: challenge.icon,
                      selected: selectedType == challenge.value,
                      badge: selectedType == challenge.value ? 'Chosen' : null,
                      onTap: () =>
                          provider.setFirstChallenge({'type': challenge.value}),
                    ),
                  ),
                )
                .toList(),
          ),
          footer: EditorialPrimaryButton(
            label: 'Finish Setup',
            onPressed: selectedType == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Choose the first challenge you want to start with.',
                        ),
                      ),
                    );
                  }
                : onNext,
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
