import 'package:flutter/material.dart';

import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class WelcomeStep extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomeStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return OnboardingStepLayout(
      eyebrow: 'Welcome',
      title: 'Let’s shape a clear gym flow.',
      subtitle: 'A few quick steps will set up your plan.',
      headerTrailing: const SizedBox(
        width: 88,
        height: 88,
        child: Center(child: Icon(Icons.auto_awesome_rounded, size: 34)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialBlurImage(
            height: 164,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Positioned(
                  left: 18,
                  top: 18,
                  child: EditorialKicker('Your setup'),
                ),
                Positioned(
                  left: 20,
                  right: 24,
                  bottom: 22,
                  child: Text(
                    'Profile, goals, nutrition, and your first challenge all come together here.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 150,
                child: OnboardingValueTile(
                  label: 'Profile',
                  value: 'Body stats',
                  icon: Icons.straighten_rounded,
                ),
              ),
              SizedBox(
                width: 150,
                child: OnboardingValueTile(
                  label: 'Goals',
                  value: 'Training focus',
                  icon: Icons.track_changes_rounded,
                ),
              ),
              SizedBox(
                width: 150,
                child: OnboardingValueTile(
                  label: 'Habits',
                  value: 'Weekly rhythm',
                  icon: Icons.bolt_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EditorialPrimaryButton(
            label: 'Start Setup',
            onPressed: onNext,
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'About a minute to your first dashboard.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
