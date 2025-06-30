import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/onboarding_provider.dart';
import 'steps/base_step.dart';

class FitnessGoalStep extends BaseStep {
  const FitnessGoalStep({
    Key? key,
    required VoidCallback onNext,
  }) : super(
    key: key,
    onNext: onNext,
    title: 'Fitness Goals',
    description: 'What do you want to achieve? (Select multiple)',
  );

  @override
  Widget buildStepContent(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return ListView(
          children: [
            _buildGoalCard(
              context,
              icon: Icons.fitness_center,
              title: 'Build Muscle',
              description: 'Gain strength and muscle mass',
              isSelected: provider.fitnessGoals.contains('muscle_gain'),
              onTap: () => provider.toggleFitnessGoal('muscle_gain'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.directions_run,
              title: 'Fat Loss',
              description: 'Burn fat and improve fitness',
              isSelected: provider.fitnessGoals.contains('fat_loss'),
              onTap: () => provider.toggleFitnessGoal('fat_loss'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.self_improvement,
              title: 'General Fitness',
              description: 'Maintain overall fitness and wellness',
              isSelected: provider.fitnessGoals.contains('general_fitness'),
              onTap: () => provider.toggleFitnessGoal('general_fitness'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.sports_gymnastics,
              title: 'Flexibility',
              description: 'Enhance mobility and balance',
              isSelected: provider.fitnessGoals.contains('flexibility'),
              onTap: () => provider.toggleFitnessGoal('flexibility'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.sports_handball,
              title: 'Strength',
              description: 'Build raw strength and power',
              isSelected: provider.fitnessGoals.contains('strength'),
              onTap: () => provider.toggleFitnessGoal('strength'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.timer,
              title: 'Endurance',
              description: 'Improve stamina and endurance',
              isSelected: provider.fitnessGoals.contains('endurance'),
              onTap: () => provider.toggleFitnessGoal('endurance'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.balance,
              title: 'Weight Maintenance',
              description: 'Maintain current weight and fitness level',
              isSelected: provider.fitnessGoals.contains('weight_maintenance'),
              onTap: () => provider.toggleFitnessGoal('weight_maintenance'),
            ),
            _buildGoalCard(
              context,
              icon: Icons.speed,
              title: 'Performance',
              description: 'Improve athletic performance',
              isSelected: provider.fitnessGoals.contains('performance'),
              onTap: () => provider.toggleFitnessGoal('performance'),
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
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
} 