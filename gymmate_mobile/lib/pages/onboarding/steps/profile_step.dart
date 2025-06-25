import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';

class ProfileStep extends StatelessWidget {
  final VoidCallback onNext;

  const ProfileStep({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    final provider = Provider.of<OnboardingProvider>(context, listen: false);
    final heightController = TextEditingController(text: provider.height > 0 ? provider.height.toString() : '');
    final weightController = TextEditingController(text: provider.weight > 0 ? provider.weight.toString() : '');
    final ageController = TextEditingController(text: provider.age > 0 ? provider.age.toString() : '');
    String? selectedGender = provider.gender;

    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Let’s Begin With You',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'We’ll start by learning a few basics about you',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(
                  labelText: 'Height (cm)',
                  hintText: 'Enter your height',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final v = double.tryParse(value ?? '');
                  if (v == null || v <= 0) return 'Please enter a valid height';
                  return null;
                },
                onChanged: (value) => provider.setHeight(double.tryParse(value) ?? 0),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  hintText: 'Enter your weight',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final v = double.tryParse(value ?? '');
                  if (v == null || v <= 0) return 'Please enter a valid weight';
                  return null;
                },
                onChanged: (value) => provider.setWeight(double.tryParse(value) ?? 0),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ageController,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: 'Enter your age',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final v = int.tryParse(value ?? '');
                  if (v == null || v <= 0) return 'Please enter a valid age';
                  return null;
                },
                onChanged: (value) => provider.setAge(int.tryParse(value) ?? 0),
              ),
              const SizedBox(height: 24),
              Text(
                'Gender',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildGenderCard(
                      context,
                      icon: Icons.male,
                      label: 'Male',
                      isSelected: provider.gender == 'male',
                      onTap: () {
                        provider.setGender('male');
                        selectedGender = 'male';
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGenderCard(
                      context,
                      icon: Icons.female,
                      label: 'Female',
                      isSelected: provider.gender == 'female',
                      onTap: () {
                        provider.setGender('female');
                        selectedGender = 'female';
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() != true || provider.gender == null || provider.gender!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill all fields and select a gender.')),
                    );
                    return;
                  }
                  onNext();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGenderCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}