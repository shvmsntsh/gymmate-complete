import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class ProfileStep extends StatefulWidget {
  final VoidCallback onNext;

  const ProfileStep({super.key, required this.onNext});

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _ageController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _heightController = TextEditingController(
      text: provider.height > 0 ? provider.height.toStringAsFixed(0) : '',
    );
    _weightController = TextEditingController(
      text: provider.weight > 0 ? provider.weight.toStringAsFixed(0) : '',
    );
    _ageController = TextEditingController(
      text: provider.age > 0 ? provider.age.toString() : '',
    );
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _continue(OnboardingProvider provider) {
    if (_formKey.currentState?.validate() != true ||
        provider.gender == null ||
        provider.gender!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add your profile basics and choose a gender to continue.',
          ),
        ),
      );
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingProvider>(
      builder: (context, provider, _) {
        return Form(
          key: _formKey,
          child: OnboardingStepLayout(
            eyebrow: 'Profile',
            title: 'Build a starting point that fits your body.',
            subtitle:
                'These details help GymMate tune pacing, recovery, and the way your progress is framed throughout the week.',
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
                        label: 'Height',
                        value: provider.height > 0
                            ? '${provider.height.toStringAsFixed(0)} cm'
                            : 'Pending',
                        icon: Icons.height_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: OnboardingValueTile(
                        label: 'Weight',
                        value: provider.weight > 0
                            ? '${provider.weight.toStringAsFixed(0)} kg'
                            : 'Pending',
                        icon: Icons.monitor_weight_outlined,
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: OnboardingValueTile(
                        label: 'Age',
                        value: provider.age > 0 ? '${provider.age}' : 'Pending',
                        icon: Icons.cake_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'Enter your height',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid height';
                    }
                    return null;
                  },
                  onChanged: (value) =>
                      provider.setHeight(double.tryParse(value) ?? 0),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'Enter your weight',
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid weight';
                    }
                    return null;
                  },
                  onChanged: (value) =>
                      provider.setWeight(double.tryParse(value) ?? 0),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    hintText: 'Enter your age',
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid age';
                    }
                    return null;
                  },
                  onChanged: (value) =>
                      provider.setAge(int.tryParse(value) ?? 0),
                ),
                const SizedBox(height: 18),
                Text('Gender', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Column(
                  children: [
                    OnboardingOptionCard(
                      title: 'Male',
                      description:
                          'Use a profile preset tailored to a male training baseline.',
                      icon: Icons.male_rounded,
                      selected: provider.gender == 'male',
                      onTap: () => provider.setGender('male'),
                    ),
                    const SizedBox(height: 12),
                    OnboardingOptionCard(
                      title: 'Female',
                      description:
                          'Use a profile preset tailored to a female training baseline.',
                      icon: Icons.female_rounded,
                      selected: provider.gender == 'female',
                      onTap: () => provider.setGender('female'),
                    ),
                  ],
                ),
              ],
            ),
            footer: EditorialPrimaryButton(
              label: 'Continue',
              onPressed: () => _continue(provider),
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
