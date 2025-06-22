import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../providers/onboarding_provider.dart';

class ChallengeStep extends StatefulWidget {
  const ChallengeStep({Key? key}) : super(key: key);

  @override
  State<ChallengeStep> createState() => _ChallengeStepState();
}

class _ChallengeStepState extends State<ChallengeStep> {
  String? _selectedChallenge;

  final _challenges = const [
    {
      'id': '7_day_checkin', 'title': '7-Day Check-in',
      'description': 'Log into the app for 7 consecutive days.',
      'reward': '+50 XP', 'icon': Icons.calendar_today_rounded,
    },
    {
      'id': 'first_workout', 'title': 'First Workout',
      'description': 'Complete your first tracked workout session.',
      'reward': '+100 XP', 'icon': Icons.fitness_center_rounded,
    },
    {
      'id': 'profile_photo', 'title': 'Update Profile',
      'description': 'Add a photo and a bio to your profile.',
      'reward': '+75 XP', 'icon': Icons.account_circle_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    // No longer trying to load initial data, state is self-contained.
  }

  void _onSave() {
    if (_selectedChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a challenge.')),
      );
      return;
    }

    final provider = context.read<OnboardingProvider>();
    provider.saveStepProgress(6, {'challengeType': _selectedChallenge});
    provider.nextStep(); // Directly call nextStep
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
                child: _buildChallengeList(),
              ),
              const SizedBox(height: 24),
              _buildContinueButton(context),
              _buildSkipButton(context),
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
          'Your First Challenge',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Kickstart your journey with a fun challenge!',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildChallengeList() {
    return ListView.separated(
      itemCount: _challenges.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final challenge = _challenges[index];
        final isSelected = _selectedChallenge == challenge['id'];
        return _buildChallengeCard(challenge, isSelected)
            .animate()
            .fadeIn(delay: (200 + index * 100).ms)
            .slideX(begin: 0.5, curve: Curves.easeOutCubic);
      },
    );
  }

  Widget _buildChallengeCard(Map<String, dynamic> challenge, bool isSelected) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : theme.dividerColor,
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surface,
      child: InkWell(
        onTap: () => setState(() => _selectedChallenge = challenge['id'] as String),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(challenge['icon'] as IconData, size: 40, color: colorScheme.primary),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge['title'] as String,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge['description'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                label: Text(challenge['reward'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: colorScheme.primary.withOpacity(0.2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return ElevatedButton.icon(
      onPressed: provider.isLoading || _selectedChallenge == null
          ? null
          : () => _onSave(),
      icon: provider.isLoading ? Container() : const Icon(Icons.check_circle_outline_rounded),
      label: provider.isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : const Text('Accept Challenge'),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return provider.isLoading
        ? const SizedBox.shrink()
        : TextButton(
            onPressed: () => _onSave(),
            child: const Text('Skip for now'),
          );
  }
} 