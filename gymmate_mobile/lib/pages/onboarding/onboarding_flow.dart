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
                      const SizedBox(height: 2),
                      Text(
                        'A few quick choices now shape a calmer training day later.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
            const SizedBox(height: 18),
            Expanded(
              child: EditorialSurface(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                radius: 34,
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
                    const SizedBox(height: 10),
                    Text(
                      _stepCaption(_currentStep),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
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
        return 'Start with the basics so your plan feels personal from day one.';
      case 1:
        return 'Profile details help pace your training and recovery more clearly.';
      case 2:
        return 'Pick the outcomes you care about most right now.';
      case 3:
        return 'Your food style helps GymMate keep nutrition guidance practical.';
      case 4:
        return 'Workout habits turn your plan into something that fits your week.';
      case 5:
        return 'A first challenge gives your training momentum an easy starting line.';
      case 6:
        return 'Everything is ready. Save your setup and head into your dashboard.';
      default:
        return '';
    }
  }
}
