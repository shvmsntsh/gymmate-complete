import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';

class GoalsStep extends StatelessWidget {
  final VoidCallback onNext;

  const GoalsStep({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final goals = [
      {
        'icon': Icons.fitness_center,
        'title': 'Build Muscle',
        'description': 'Gain strength and muscle mass',
        'value': 'muscle_gain',
      },
      {
        'icon': Icons.directions_run,
        'title': 'Fat Loss',
        'description': 'Burn fat and improve fitness',
        'value': 'fat_loss',
      },
      {
        'icon': Icons.self_improvement,
        'title': 'General Fitness',
        'description': 'Maintain overall fitness and well-being',
        'value': 'general_fitness',
      },
      {
        'icon': Icons.sports_score,
        'title': 'Performance',
        'description': 'Enhance athletic abilities',
        'value': 'performance',
      },
      {
        'icon': Icons.sports_handball,
        'title': 'Strength',
        'description': 'Build raw strength and power',
        'value': 'strength',
      },
      {
        'icon': Icons.timer,
        'title': 'Endurance',
        'description': 'Improve stamina and endurance',
        'value': 'endurance',
      },
      {
        'icon': Icons.sports_gymnastics,
        'title': 'Flexibility',
        'description': 'Enhance mobility and flexibility',
        'value': 'flexibility',
      },
      {
        'icon': Icons.balance,
        'title': 'Weight Maintenance',
        'description': 'Maintain current weight and fitness',
        'value': 'weight_maintenance',
      },
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Your Goals',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'What do you want to achieve? (Select multiple)',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: goals.map((goal) => _buildGoalCard(
                  context,
                  icon: goal['icon'] as IconData,
                  title: goal['title'] as String,
                  description: goal['description'] as String,
                  isSelected: provider.fitnessGoals.contains(goal['value']),
                  onSelect: () => provider.toggleFitnessGoal(goal['value'] as String),
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  if (provider.fitnessGoals.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one fitness goal.')),
                    );
                    return;
                  }
                  onNext();
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onSelect,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}