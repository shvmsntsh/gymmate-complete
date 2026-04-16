import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/main.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_onboarding.dart';

class CompletionStep extends StatelessWidget {
  final VoidCallback onNext;

  const CompletionStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _CompletionContent(onNext: onNext);
  }
}

class _CompletionContent extends StatefulWidget {
  final VoidCallback onNext;

  const _CompletionContent({required this.onNext});

  @override
  State<_CompletionContent> createState() => _CompletionContentState();
}

class _CompletionContentState extends State<_CompletionContent> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 4),
    )..play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final provider = context.read<OnboardingProvider>();
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session expired. Please log in again.'),
        ),
      );
      return;
    }

    final success = await provider.completeOnboarding(token);
    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not save your setup right now. Please try again.',
          ),
        ),
      );
      return;
    }

    await authProvider.completeOnboarding();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScaffold(initialTab: 0),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.04,
            numberOfParticles: 32,
            gravity: 0.05,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFB59D),
              Color(0xFFFF5711),
              Color(0xFFFFD6C2),
              Color(0xFF80CBC4),
            ],
          ),
        ),
        OnboardingStepLayout(
          eyebrow: 'Ready',
          title: 'Your GymMate space is ready.',
          subtitle: 'Save once, then step into your first dashboard.',
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
                      label: 'Goals',
                      value: provider.fitnessGoals.isEmpty
                          ? 'Pending'
                          : '${provider.fitnessGoals.length} chosen',
                      icon: Icons.track_changes_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: OnboardingValueTile(
                      label: 'Diet',
                      value: _titleCase(
                        provider.dietPreferences['type'] as String?,
                      ),
                      icon: Icons.restaurant_rounded,
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: OnboardingValueTile(
                      label: 'Challenge',
                      value: _titleCase(
                        provider.firstChallenge['type'] as String?,
                      ),
                      icon: Icons.emoji_events_outlined,
                    ),
                  ),
                ],
              ),
            ],
          ),
          footer: EditorialPrimaryButton(
            label: 'Save and Enter Dashboard',
            onPressed: _saveAndContinue,
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  static String _titleCase(String? value) {
    if (value == null || value.isEmpty) return 'Pending';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
