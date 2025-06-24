import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class WorkoutStep extends StatefulWidget {
  final String? userId;
  final String? token;
  const WorkoutStep({Key? key, this.userId, this.token}) : super(key: key);

  @override
  State<WorkoutStep> createState() => _WorkoutStepState();
}

class _WorkoutStepState extends State<WorkoutStep> {
  String? _activityLevel;
  int _workoutsPerWeek = 0;
  final Set<String> _favoriteExercises = {};
  TimeOfDay? _preferredTime;

  final _exerciseTypes = const [
    {'id': 'cardio', 'name': 'Cardio', 'icon': Icons.directions_run_rounded},
    {'id': 'weight_training', 'name': 'Weights', 'icon': Icons.fitness_center_rounded},
    {'id': 'yoga', 'name': 'Yoga', 'icon': Icons.self_improvement_rounded},
    {'id': 'swimming', 'name': 'Swimming', 'icon': Icons.pool_rounded},
    {'id': 'crossfit', 'name': 'CrossFit', 'icon': Icons.sports_gymnastics_rounded},
  ];

  @override
  void initState() {
    super.initState();
    // No longer loading data from provider on init.
  }

  void _onSave() {
    if (_activityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your activity level.')),
      );
      return;
    }

    final provider = context.read<OnboardingProvider>();
    final data = {
      'currentActivityLevel': _activityLevel,
      'favoriteExercises': _favoriteExercises.toList(),
      'preferredTime': _preferredTime != null ? _getTimeEnum(_preferredTime!) : null,
      'workoutsPerWeek': _workoutsPerWeek,
    };
    provider.saveStepProgress(5, data);
    provider.nextStep();
  }

  String _getTimeEnum(TimeOfDay time) {
    final hour = time.hour;
    if (hour < 6) return 'early_morning';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  @override
  Widget build(BuildContext context) {
    print('WorkoutStep build called');
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                children: [
                  _buildSectionHeader('Preferred Workout Time'),
                  _buildTimePicker(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Current Activity Level'),
                  _buildActivityLevelSelector(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Workouts per Week'),
                  _buildWorkoutDaysSelector(),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Favorite Exercise Types'),
                  _buildExerciseChips(),
                  const SizedBox(height: 40),
                  _buildContinueButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Your Workout Habits',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'When and how do you like to exercise?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context) {
    return ListTile(
      title: const Text('Preferred Workout Time'),
      subtitle: Text(_preferredTime?.format(context) ?? 'Tap to select'),
      trailing: const Icon(Icons.access_time),
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _preferredTime ?? const TimeOfDay(hour: 17, minute: 0),
        );
        if (time != null) {
          setState(() {
            _preferredTime = time;
          });
        }
      },
    );
  }

  Widget _buildActivityLevelSelector() {
    const levels = {
      'sedentary': 'Sedentary', 'lightly_active': 'Lightly Active',
      'moderately_active': 'Moderately Active', 'very_active': 'Very Active'
    };
    return _buildChipSelector(
      options: levels,
      selectedOption: _activityLevel,
      onSelected: (value) => setState(() => _activityLevel = value),
    );
  }

  Widget _buildWorkoutDaysSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How many days per week?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: _workoutsPerWeek.toDouble(),
          min: 0,
          max: 7,
          divisions: 7,
          label: _workoutsPerWeek.toString(),
          onChanged: (value) => setState(() {
            _workoutsPerWeek = value.round();
          }),
        ),
      ],
    );
  }

  Widget _buildChipSelector({
    required Map<String, String> options,
    required String? selectedOption,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) {
        final isSelected = selectedOption == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          onSelected: (_) => onSelected(entry.key),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildExerciseChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _exerciseTypes.map((exercise) {
        final isSelected = _favoriteExercises.contains(exercise['id']);
        return FilterChip(
          label: Text(exercise['name'] as String),
          avatar: Icon(exercise['icon'] as IconData, size: 18),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _favoriteExercises.add(exercise['id'] as String);
              } else {
                _favoriteExercises.remove(exercise['id'] as String);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return ElevatedButton(
      onPressed: _activityLevel == null || provider.isLoading ? null : _onSave,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      child: provider.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Text('Save & Continue'),
    );
  }
} 