import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';

class WorkoutStep extends StatelessWidget {
  final VoidCallback onNext;

  const WorkoutStep({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final activityLevels = [
      {'label': 'Sedentary', 'value': 'sedentary'},
      {'label': 'Lightly Active', 'value': 'lightly_active'},
      {'label': 'Moderately Active', 'value': 'moderately_active'},
      {'label': 'Very Active', 'value': 'very_active'},
      {'label': 'Extremely Active', 'value': 'extremely_active'},
    ];
    final preferredTimes = [
      {'label': 'Early Morning', 'value': 'early_morning'},
      {'label': 'Morning', 'value': 'morning'},
      {'label': 'Afternoon', 'value': 'afternoon'},
      {'label': 'Evening', 'value': 'evening'},
      {'label': 'Night', 'value': 'night'},
      {'label': 'Flexible', 'value': 'flexible'},
    ];
    final exerciseTypes = [
      {'label': 'Cardio', 'value': 'cardio'},
      {'label': 'Weight Training', 'value': 'weight_training'},
      {'label': 'Yoga', 'value': 'yoga'},
      {'label': 'Swimming', 'value': 'swimming'},
      {'label': 'CrossFit', 'value': 'crossfit'},
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final habits = provider.workoutHabits;
        final favoriteExercises = List<String>.from(habits['favoriteExercises'] ?? []);
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Workout Preferences',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us about your workout style',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text('Activity Level', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: activityLevels.map((level) => ChoiceChip(
                    label: Text(level['label']!),
                    selected: habits['currentActivityLevel'] == level['value'],
                    onSelected: (_) {
                      provider.setWorkoutHabits({
                        ...habits,
                        'currentActivityLevel': level['value'],
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Text('Preferred Time', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: preferredTimes.map((time) => ChoiceChip(
                    label: Text(time['label']!),
                    selected: habits['preferredTime'] == time['value'],
                    onSelected: (_) {
                      provider.setWorkoutHabits({
                        ...habits,
                        'preferredTime': time['value'],
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Text('Favorite Exercises', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: exerciseTypes.map((ex) => FilterChip(
                    label: Text(ex['label']!),
                    selected: favoriteExercises.contains(ex['value']),
                    onSelected: (selected) {
                      final favs = List<String>.from(favoriteExercises);
                      if (selected) {
                        if (!favs.contains(ex['value'])) favs.add(ex['value']!);
                      } else {
                        favs.remove(ex['value']);
                      }
                      provider.setWorkoutHabits({
                        ...habits,
                        'favoriteExercises': favs,
                        'preferredTime': habits['preferredTime'],
                        'currentActivityLevel': habits['currentActivityLevel'],
                        'workoutsPerWeek': habits['workoutsPerWeek'] ?? 0,
                        'sessionDuration': habits['sessionDuration'] ?? 60,
                        'hasInjuries': habits['hasInjuries'] ?? false,
                        'injuryDetails': habits['injuryDetails'],
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 16),
                Text('Workouts Per Week', style: Theme.of(context).textTheme.titleMedium),
                Slider(
                  value: (habits['workoutsPerWeek'] is num && (habits['workoutsPerWeek'] ?? 0) >= 1)
                      ? (habits['workoutsPerWeek'] as num).toDouble()
                      : 1.0,
                  min: 1,
                  max: 14,
                  divisions: 14,
                  label: '${habits['workoutsPerWeek'] ?? 1}',
                  onChanged: (value) {
                    provider.setWorkoutHabits({
                      ...habits,
                      'workoutsPerWeek': value.round(),
                      'favoriteExercises': favoriteExercises,
                      'preferredTime': habits['preferredTime'],
                      'currentActivityLevel': habits['currentActivityLevel'],
                      'sessionDuration': habits['sessionDuration'] ?? 60,
                      'hasInjuries': habits['hasInjuries'] ?? false,
                      'injuryDetails': habits['injuryDetails'],
                    });
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    String? error;
                    if (habits['currentActivityLevel'] == null) {
                      error = 'Please select your activity level.';
                    } else if (habits['preferredTime'] == null) {
                      error = 'Please select your preferred workout time.';
                    } else if ((habits['workoutsPerWeek'] ?? 0) <= 0) {
                      error = 'Please set how many workouts you do per week.';
                    } else if (habits['favoriteExercises'] == null || (habits['favoriteExercises'] as List).isEmpty) {
                      error = 'Please select at least one favorite exercise.';
                    }
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error)),
                      );
                      return;
                    }
                    onNext();
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}