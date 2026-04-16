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
        title: '7-Day Check-in',
        value: '7_day_checkin',
        description: 'Log something on 7 different days.',
      ),
      (
        icon: Icons.timer_outlined,
        title: 'First Workout',
        value: 'first_workout',
        description: 'Complete your first logged workout.',
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        title: 'Meal Rhythm',
        value: 'meal_rhythm',
        description: 'Finish your planned meals across 3 days.',
      ),
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selectedType = provider.firstChallenge['type'] as String?;

        return OnboardingStepLayout(
          eyebrow: 'Challenge',
          title: 'Pick one starter target.',
          subtitle: 'Choose one challenge you can track from real activity.',
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
