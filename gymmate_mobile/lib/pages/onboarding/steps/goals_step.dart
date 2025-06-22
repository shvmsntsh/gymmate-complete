import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class GoalsStep extends StatefulWidget {
  const GoalsStep({Key? key}) : super(key: key);

  @override
  State<GoalsStep> createState() => _GoalsStepState();
}

class _GoalsStepState extends State<GoalsStep> {
  final List<String> _selectedGoals = [];

  final List<Map<String, dynamic>> _fitnessGoals = [
    {'id': 'muscle_gain', 'title': 'Build Muscle', 'icon': Icons.fitness_center_rounded},
    {'id': 'fat_loss', 'title': 'Lose Fat', 'icon': Icons.local_fire_department_rounded},
    {'id': 'endurance', 'title': 'Improve Endurance', 'icon': Icons.directions_run_rounded},
    {'id': 'flexibility', 'title': 'Increase Flexibility', 'icon': Icons.self_improvement_rounded},
    {'id': 'strength', 'title': 'Gain Strength', 'icon': Icons.whatshot_rounded},
    {'id': 'general_fitness', 'title': 'General Fitness', 'icon': Icons.favorite_rounded},
  ];

  @override
  void initState() {
    super.initState();
  }

  void _toggleGoal(String goalId) {
    setState(() {
      if (_selectedGoals.contains(goalId)) {
        _selectedGoals.remove(goalId);
      } else {
        _selectedGoals.add(goalId);
      }
    });
  }

  void _onSave() {
    if (_selectedGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one goal.')),
      );
      return;
    }

    final provider = context.read<OnboardingProvider>();
    provider.saveStepProgress(3, {'fitnessGoals': _selectedGoals});
    provider.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: _buildGoalsGrid(),
              ),
              const SizedBox(height: 24),
              _buildContinueButton(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What are your fitness goals?',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all that apply. You can change these later.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2);
  }

  Widget _buildGoalsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _fitnessGoals.length,
      itemBuilder: (context, index) {
        final goal = _fitnessGoals[index];
        final isSelected = _selectedGoals.contains(goal['id']);
        return _buildGoalCard(goal, isSelected)
            .animate()
            .fadeIn(delay: (200 + index * 50).ms)
            .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack);
      },
    );
  }

  Widget _buildGoalCard(Map<String, dynamic> goal, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _toggleGoal(goal['id'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(goal['icon'] as IconData, size: 40, color: isSelected ? colorScheme.primary : theme.iconTheme.color),
            const SizedBox(height: 16),
            Text(
              goal['title'] as String,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? colorScheme.primary : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _onSave,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
      ),
      child: const Text('Save & Continue'),
    );
  }
}