import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class DietStep extends StatelessWidget {
  final VoidCallback onNext;

  const DietStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final dietTypes = [
      (
        icon: Icons.eco_outlined,
        title: 'Vegetarian',
        value: 'vegetarian',
        description: 'Plant-forward meals with dairy or eggs where needed.',
      ),
      (
        icon: Icons.spa_outlined,
        title: 'Vegan',
        value: 'vegan',
        description: 'Fully plant-based nutrition from breakfast to recovery.',
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        title: 'Non-Vegetarian',
        value: 'non_vegetarian',
        description: 'A broader menu with full protein and meal variety.',
      ),
      (
        icon: Icons.tune_rounded,
        title: 'Flexible',
        value: 'flexible',
        description: 'A balanced approach without strict food boundaries.',
      ),
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selectedType = provider.dietPreferences['type'] as String?;

        return OnboardingStepLayout(
          eyebrow: 'Nutrition',
          title: 'Set a food style that fits your week.',
          subtitle: 'Choose the meal style that feels most natural.',
          body: Column(
            children: dietTypes
                .map(
                  (diet) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OnboardingOptionCard(
                      title: diet.title,
                      description: diet.description,
                      icon: diet.icon,
                      selected: selectedType == diet.value,
                      onTap: () {
                        provider.setDietPreferences({
                          ...provider.dietPreferences,
                          'type': diet.value,
                        });
                      },
                    ),
                  ),
                )
                .toList(),
          ),
          footer: EditorialPrimaryButton(
            label: 'Continue',
            onPressed: selectedType == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Choose the meal style you want GymMate to follow.',
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
