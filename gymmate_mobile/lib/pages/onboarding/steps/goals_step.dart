import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class GoalsStep extends StatelessWidget {
  final VoidCallback onNext;

  const GoalsStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final goals = [
      (
        icon: Icons.fitness_center_rounded,
        title: 'Build Muscle',
        description: 'Add size, strength, and a steadier lifting rhythm.',
        value: 'muscle_gain',
      ),
      (
        icon: Icons.local_fire_department_outlined,
        title: 'Fat Loss',
        description: 'Lean out while keeping training momentum intact.',
        value: 'fat_loss',
      ),
      (
        icon: Icons.favorite_outline_rounded,
        title: 'General Fitness',
        description:
            'Feel stronger, lighter, and more consistent week to week.',
        value: 'general_fitness',
      ),
      (
        icon: Icons.sports_martial_arts_rounded,
        title: 'Performance',
        description: 'Train for sharper speed, output, and athletic control.',
        value: 'performance',
      ),
      (
        icon: Icons.hardware_rounded,
        title: 'Strength',
        description: 'Prioritize heavier lifts and raw force production.',
        value: 'strength',
      ),
      (
        icon: Icons.directions_run_rounded,
        title: 'Endurance',
        description: 'Build the stamina to move better for longer sessions.',
        value: 'endurance',
      ),
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return OnboardingStepLayout(
          eyebrow: 'Goals',
          title: 'Choose the outcomes you want your training to chase.',
          subtitle:
              'Pick one or more priorities. GymMate will keep these goals at the center of your plan and progress story.',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: provider.fitnessGoals.isEmpty
                    ? const [
                        OnboardingChipOption(
                          label: 'Select at least one goal',
                          selected: false,
                          onTap: null,
                        ),
                      ]
                    : provider.fitnessGoals
                          .map(
                            (goal) => OnboardingChipOption(
                              label: _titleFor(goal),
                              selected: true,
                              onTap: () => provider.toggleFitnessGoal(goal),
                            ),
                          )
                          .toList(),
              ),
              const SizedBox(height: 16),
              Column(
                children: goals
                    .map(
                      (goal) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OnboardingOptionCard(
                          title: goal.title,
                          description: goal.description,
                          icon: goal.icon,
                          selected: provider.fitnessGoals.contains(goal.value),
                          onTap: () => provider.toggleFitnessGoal(goal.value),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          footer: EditorialPrimaryButton(
            label: 'Keep Going',
            onPressed: provider.fitnessGoals.isEmpty
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Choose at least one training goal to continue.',
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

  static String _titleFor(String goal) {
    switch (goal) {
      case 'muscle_gain':
        return 'Build Muscle';
      case 'fat_loss':
        return 'Fat Loss';
      case 'general_fitness':
        return 'General Fitness';
      case 'performance':
        return 'Performance';
      case 'strength':
        return 'Strength';
      case 'endurance':
        return 'Endurance';
      default:
        return goal;
    }
  }
}
