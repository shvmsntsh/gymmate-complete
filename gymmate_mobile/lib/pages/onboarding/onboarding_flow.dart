import 'package:flutter/material.dart';
import 'steps/profile_step.dart';
import 'steps/goals_step.dart';
import 'steps/diet_step.dart';
import 'steps/workout_step.dart';
import 'steps/challenge_step.dart';
import 'steps/completion_step.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ProfileStep(
          onNext: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const Text('Dashboard')),
                  body: SafeArea(
                    child: GoalsStep(
                      onNext: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              appBar: AppBar(title: const Text('Dashboard')),
                              body: SafeArea(
                                child: DietStep(
                                  onNext: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => Scaffold(
                                          appBar: AppBar(title: const Text('Dashboard')),
                                          body: SafeArea(
                                            child: WorkoutStep(
                                              onNext: () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (context) => Scaffold(
                                                      appBar: AppBar(title: const Text('Dashboard')),
                                                      body: SafeArea(
                                                        child: ChallengeStep(
                                                          onNext: () {
                                                            Navigator.of(context).push(
                                                              MaterialPageRoute(
                                                                builder: (context) => Scaffold(
                                                                  appBar: AppBar(title: const Text('Dashboard')),
                                                                  body: SafeArea(
                                                                    child: CompletionStep(
                                                                      onNext: () {
                                                                        // Final onboarding complete logic can go here
                                                                      },
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}