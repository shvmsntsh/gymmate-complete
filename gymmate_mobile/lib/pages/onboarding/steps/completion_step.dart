import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';
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
    final title = const Text(
      'Welcome to GymMate!',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
    final description = const Text(
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
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
            const Icon(
              Icons.check_circle_outline,
              size: 120,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            const Text(
              'Congratulations!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'ve filled the onboarding details.',
          textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
        ),
            const SizedBox(height: 32),
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
                  widget.onNext();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to complete onboarding')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Save and Start Your Journey'),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
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
      ],
    );
  }
}