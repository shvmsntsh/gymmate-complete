import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';


class DietStep extends StatelessWidget {
  final VoidCallback onNext;
  const DietStep({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dietTypes = [
      {'icon': Icons.restaurant_menu, 'label': 'Vegetarian', 'value': 'vegetarian', 'desc': 'Plant-based diet with dairy and eggs'},
      {'icon': Icons.grass, 'label': 'Vegan', 'value': 'vegan', 'desc': 'Strictly plant-based diet'},
      {'icon': Icons.set_meal, 'label': 'Non-Vegetarian', 'value': 'non_vegetarian', 'desc': 'Includes all food groups'},
      {'icon': Icons.food_bank, 'label': 'Flexible', 'value': 'flexible', 'desc': 'No specific dietary restrictions'},
    ];

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        final selectedType = provider.dietPreferences['type'];
        print('[DietStep] provider.dietPreferences["type"]: $selectedType');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Diet Preferences',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Tell us about your eating habits',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: dietTypes.map((diet) => _buildDietCard(
                  context,
                  icon: diet['icon'] as IconData,
                  title: diet['label'] as String,
                  description: diet['desc'] as String,
                  isSelected: selectedType == diet['value'],
                  onSelect: () {
                    provider.setDietPreferences({
                      ...provider.dietPreferences,
                      'type': diet['value'],
                    });
                  },
                )).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  if (provider.dietPreferences['type'] == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a diet preference.')),
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

  Widget _buildDietCard(
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