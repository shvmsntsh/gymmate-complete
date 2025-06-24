import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class DietStep extends StatefulWidget {
  final String? userId;
  final String? token;
  const DietStep({Key? key, this.userId, this.token}) : super(key: key);

  @override
  State<DietStep> createState() => _DietStepState();
}

class _DietStepState extends State<DietStep> {
  String? _dietType;
  String? _allergies;
  int _dailyMeals = 3;
  double _waterIntake = 2.0;

  final List<Map<String, String>> _dietTypes = [
    {'id': 'vegetarian', 'name': 'Vegetarian', 'icon': '🥗'},
    {'id': 'non_vegetarian', 'name': 'Non-Vegetarian', 'icon': '🍗'},
    {'id': 'vegan', 'name': 'Vegan', 'icon': '🥑'},
    {'id': 'keto', 'name': 'Keto', 'icon': '🥩'},
    {'id': 'paleo', 'name': 'Paleo', 'icon': '🍖'},
    {'id': 'mediterranean', 'name': 'Mediterranean', 'icon': '🐟'},
    {'id': 'other', 'name': 'Other', 'icon': '❓'},
  ];

  final List<String> _dietOptions = [
    'High Protein',
    'Balanced',
    'Low Carb',
    'Vegetarian',
    'Vegan'
  ];

  @override
  void initState() {
    super.initState();
    // State is now self-contained, not loading from provider.
  }

  void _onSave() {
    if (_dietType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a diet type.')),
      );
      return;
    }

    final provider = context.read<OnboardingProvider>();
    final data = {
      'type': _dietType,
      'allergies': _allergies != null && _allergies!.isNotEmpty ? [_allergies] : [],
      'dailyMeals': _dailyMeals,
      'waterIntake': _waterIntake,
    };
    provider.saveStepProgress(4, data);
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
              const SizedBox(height: 32),
              Expanded(
                child: _buildDietOptions(),
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
          'Your Diet Preferences',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell us about your dietary habits to get better recommendations.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2);
  }

  Widget _buildDietOptions() {
    return ListView(
      children: _dietTypes.map((diet) {
        final isSelected = _dietType == diet['id'];
        return _buildDietCard(diet, isSelected)
            .animate()
            .fadeIn(delay: (200 + _dietTypes.indexOf(diet) * 50).ms)
            .slideX(begin: 0.5, curve: Curves.easeOutCubic);
      }).toList(),
    );
  }

  Widget _buildDietCard(Map<String, String> diet, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : theme.dividerColor,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      color: isSelected ? colorScheme.primary.withAlpha(102) : colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _dietType = diet['id']),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(diet['icon']!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  diet['name']!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? colorScheme.primary : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return ElevatedButton(
      onPressed: _dietType == null || provider.isLoading ? null : _onSave,
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