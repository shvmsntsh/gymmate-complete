import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class WorkoutStep extends StatelessWidget {
  final VoidCallback onNext;

  const WorkoutStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    const activityLevels = [
      ('Sedentary', 'sedentary'),
      ('Lightly Active', 'lightly_active'),
      ('Moderately Active', 'moderately_active'),
      ('Very Active', 'very_active'),
      ('Extremely Active', 'extremely_active'),
    ];
    const preferredTimes = [
      ('Early Morning', 'early_morning'),
      ('Morning', 'morning'),
      ('Afternoon', 'afternoon'),
      ('Evening', 'evening'),
      ('Night', 'night'),
      ('Flexible', 'flexible'),
    ];
    const exerciseTypes = [
      ('Cardio', 'cardio'),
      ('Weight Training', 'weight_training'),
      ('Yoga', 'yoga'),
      ('Swimming', 'swimming'),
      ('CrossFit', 'crossfit'),
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final habits = provider.workoutHabits;
        final favoriteExercises = List<String>.from(
          habits['favoriteExercises'] ?? const <String>[],
        );
        final workoutsPerWeek =
            (habits['workoutsPerWeek'] as num?)?.toDouble() ?? 3;

        void updateHabits(Map<String, dynamic> patch) {
          provider.setWorkoutHabits({
            ...habits,
            'favoriteExercises': favoriteExercises,
            'preferredTime': habits['preferredTime'],
            'currentActivityLevel': habits['currentActivityLevel'],
            'workoutsPerWeek': habits['workoutsPerWeek'] ?? 3,
            'sessionDuration': habits['sessionDuration'] ?? 60,
            'hasInjuries': habits['hasInjuries'] ?? false,
            'injuryDetails': habits['injuryDetails'],
            ...patch,
          });
        }

        return OnboardingStepLayout(
          eyebrow: 'Workout',
          title: 'Lock in the rhythm that matches your week.',
          subtitle:
              'Training works better when it fits your real schedule. Share your pace, timing, and favorite styles here.',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 150,
                    child: OnboardingValueTile(
                      label: 'Weekly sessions',
                      value: '${workoutsPerWeek.round()}x',
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: OnboardingValueTile(
                      label: 'Best time',
                      value: _friendlyTime(habits['preferredTime'] as String?),
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Activity level',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: activityLevels
                    .map(
                      (level) => OnboardingChipOption(
                        label: level.$1,
                        selected: habits['currentActivityLevel'] == level.$2,
                        onTap: () =>
                            updateHabits({'currentActivityLevel': level.$2}),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Preferred time',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: preferredTimes
                    .map(
                      (time) => OnboardingChipOption(
                        label: time.$1,
                        selected: habits['preferredTime'] == time.$2,
                        onTap: () => updateHabits({'preferredTime': time.$2}),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text(
                'Favorite training styles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: exerciseTypes
                    .map(
                      (exercise) => OnboardingChipOption(
                        label: exercise.$1,
                        selected: favoriteExercises.contains(exercise.$2),
                        onTap: () {
                          final next = List<String>.from(favoriteExercises);
                          if (next.contains(exercise.$2)) {
                            next.remove(exercise.$2);
                          } else {
                            next.add(exercise.$2);
                          }
                          updateHabits({'favoriteExercises': next});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Workouts per week',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: workoutsPerWeek.clamp(1, 14),
                min: 1,
                max: 14,
                divisions: 13,
                label: '${workoutsPerWeek.round()}',
                onChanged: (value) =>
                    updateHabits({'workoutsPerWeek': value.round()}),
              ),
            ],
          ),
          footer: EditorialPrimaryButton(
            label: 'Continue',
            onPressed: () {
              String? error;
              if (habits['currentActivityLevel'] == null) {
                error = 'Choose an activity level first.';
              } else if (habits['preferredTime'] == null) {
                error = 'Choose a training time that fits your routine.';
              } else if (favoriteExercises.isEmpty) {
                error = 'Choose at least one training style you enjoy.';
              }

              if (error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(error)));
                return;
              }

              onNext();
            },
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  static String _friendlyTime(String? value) {
    switch (value) {
      case 'early_morning':
        return 'Early';
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'evening':
        return 'Evening';
      case 'night':
        return 'Night';
      case 'flexible':
        return 'Flexible';
      default:
        return 'Open';
    }
  }
}
