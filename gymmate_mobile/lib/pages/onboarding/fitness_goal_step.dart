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
    description: 'What do you want to achieve?',
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
              isSelected: false,
              onTap: () {
                // Handle goal selection
              },
            ),
            _buildGoalCard(
              context,
              icon: Icons.directions_run,
              title: 'Lose Weight',
              description: 'Burn fat and improve fitness',
              isSelected: false,
              onTap: () {
                // Handle goal selection
              },
            ),
            _buildGoalCard(
              context,
              icon: Icons.self_improvement,
              title: 'Stay Healthy',
              description: 'Maintain fitness and wellness',
              isSelected: false,
              onTap: () {
                // Handle goal selection
              },
            ),
            _buildGoalCard(
              context,
              icon: Icons.sports_gymnastics,
              title: 'Improve Flexibility',
              description: 'Enhance mobility and balance',
              isSelected: false,
              onTap: () {
                // Handle goal selection
              },
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