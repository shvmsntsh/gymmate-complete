import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class ProfileStep extends StatefulWidget {
  const ProfileStep({Key? key}) : super(key: key);

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  final _formKey = GlobalKey<FormState>();
  String _displayName = '';
  int? _age;
  String? _gender;
  double? _weight;
  double? _height;

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            children: [
              _buildHeader(context),
              const SizedBox(height: 32),
              ..._buildFormFields(),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Save & Continue'),
              ),
            ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideX(begin: 0.2),
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
          'Tell us about yourself',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us personalize your fitness experience.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  List<Widget> _buildFormFields() {
    return [
      _buildNameField(),
      const SizedBox(height: 20),
      _buildAgeField(),
      const SizedBox(height: 20),
      _buildGenderField(),
      const SizedBox(height: 20),
      _buildWeightField(),
      const SizedBox(height: 20),
      _buildHeightField(),
    ];
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _displayName,
      decoration: const InputDecoration(
        labelText: 'Display Name',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Please enter your name' : null,
      onSaved: (value) => _displayName = value!.trim(),
    );
  }

  Widget _buildAgeField() {
    return TextFormField(
      initialValue: _age?.toString(),
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Age',
        prefixIcon: Icon(Icons.cake_outlined),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Please enter your age';
        final age = int.tryParse(value);
        if (age == null || age < 13 || age > 120) return 'Please enter a valid age (13-120)';
        return null;
      },
      onSaved: (value) => _age = int.tryParse(value!),
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _gender,
      decoration: const InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.wc_rounded),
      ),
      items: _genderOptions.map((gender) {
        return DropdownMenuItem(
          value: gender,
          child: Text(_getGenderDisplayName(gender)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _gender = value),
      validator: (value) => (value == null || value.isEmpty) ? 'Please select your gender' : null,
      onSaved: (value) => _gender = value,
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      initialValue: _weight?.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Weight',
        prefixIcon: Icon(Icons.monitor_weight_outlined),
        suffixText: 'kg',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Please enter your weight';
        final weight = double.tryParse(value);
        if (weight == null || weight < 20 || weight > 500) return 'Please enter a valid weight (20-500 kg)';
        return null;
      },
      onSaved: (value) => _weight = double.tryParse(value!),
    );
  }

  Widget _buildHeightField() {
    return TextFormField(
      initialValue: _height?.toString(),
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Height',
        prefixIcon: Icon(Icons.height_rounded),
        suffixText: 'cm',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Please enter your height';
        final height = double.tryParse(value);
        if (height == null || height < 100 || height > 250) return 'Please enter a valid height (100-250 cm)';
        return null;
      },
      onSaved: (value) => _height = double.tryParse(value!),
    );
  }

  String _getGenderDisplayName(String gender) {
    switch (gender) {
      case 'Male': return 'Male';
      case 'Female': return 'Female';
      case 'Other': return 'Other';
      case 'Prefer not to say': return 'Prefer not to say';
      default: return gender;
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final provider = context.read<OnboardingProvider>();
    final data = {
      'displayName': _displayName,
      'age': _age,
      'gender': _gender,
      'weight': _weight,
      'height': _height,
    };
    provider.saveStepProgress(2, data);
    provider.nextStep();
  }
}