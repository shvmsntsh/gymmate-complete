import 'package:flutter/material.dart';

import 'package:gymmate_mobile/widgets/editorial_mobile.dart';

import 'steps/challenge_step.dart';
import 'steps/completion_step.dart';
import 'steps/diet_step.dart';
import 'steps/goals_step.dart';
import 'steps/profile_step.dart';
import 'steps/welcome_step.dart';
import 'steps/workout_step.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _currentStep = 0;

  void _goNext() {
    if (_currentStep >= _stepCount - 1) return;
    setState(() {
      _currentStep += 1;
    });
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _currentStep -= 1;
    });
  }

  int get _stepCount => 7;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (_currentStep + 1) / _stepCount;
    final steps = <Widget>[
      WelcomeStep(onNext: _goNext),
      ProfileStep(onNext: _goNext),
      GoalsStep(onNext: _goNext),
      DietStep(onNext: _goNext),
      WorkoutStep(onNext: _goNext),
      ChallengeStep(onNext: _goNext),
      CompletionStep(onNext: () {}),
    ];

    return Scaffold(
      body: EditorialBackdrop(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: 0.84,
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Build your rhythm',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Quick choices now make training easier later.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentStep + 1}/$_stepCount',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: EditorialSurface(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                radius: 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepCaption(_currentStep),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: IndexedStack(index: _currentStep, children: steps),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stepCaption(int step) {
    switch (step) {
      case 0:
        return 'Start with the basics.';
      case 1:
        return 'Profile details shape your plan.';
      case 2:
        return 'Choose your main goals.';
      case 3:
        return 'Set your food style.';
      case 4:
        return 'Match the plan to your week.';
      case 5:
        return 'Pick a trackable challenge.';
      case 6:
        return 'Save and enter your dashboard.';
      default:
        return '';
    }
  }
}
