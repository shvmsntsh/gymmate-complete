import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../main.dart';
import '../../plan_page.dart';
// Removed import of 'base_step.dart'

class CompletionStep extends StatelessWidget {
  final VoidCallback onNext;

  const CompletionStep({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Static title and description widgets
    final title = Text(
      'Welcome to GymMate!',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
    const description = Text(
      'Your fitness journey starts now',
      style: TextStyle(
        fontSize: 16,
      ),
      textAlign: TextAlign.center,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        title,
        const SizedBox(height: 16),
        description,
        const SizedBox(height: 32),
        _CompletionContent(onNext: onNext),
      ],
    );
  }
}

class _CompletionContent extends StatefulWidget {
  final VoidCallback onNext;

  const _CompletionContent({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  State<_CompletionContent> createState() => _CompletionContentState();
}

class _CompletionContentState extends State<_CompletionContent> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.05,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final provider = Provider.of<OnboardingProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final token = authProvider.token;

                if (token == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Authentication token missing')),
                  );
                  return;
                }

                bool success = await provider.completeOnboarding(token);
                if (success) {
                  await authProvider.completeOnboarding();
                  if (context.mounted) {
                    // Navigate to the MainNavigationScaffold and show PlanPage (Plan tab)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainNavigationScaffold(initialTab: 1)),
                      (route) => false,
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to complete onboarding')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Save and Continue with Your Journey'),
            ),
          ],
        ),
      ],
    );
  }
}