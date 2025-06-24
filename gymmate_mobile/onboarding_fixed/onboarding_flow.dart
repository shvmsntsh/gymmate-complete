import 'package:flutter/material.dart';
import 'profile_step.dart';
import 'diet_step.dart';
import 'workout_step.dart';
import 'goals_step.dart';
import 'fitness_goal_step.dart';
import 'completion_step.dart';

class OnboardingFlow extends StatefulWidget {
  final String userId;
  const OnboardingFlow({Key? key, required this.userId}) : super(key: key);

  @override
  _OnboardingFlowState createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late final List<Widget> _steps;

  @override
  void initState() {
    super.initState();
    _steps = [
      ProfileStep(userId: widget.userId),
      DietStep(userId: widget.userId),
      WorkoutStep(userId: widget.userId),
      GoalsStep(userId: widget.userId),
      FitnessGoalStep(userId: widget.userId),
      CompletionStep(userId: widget.userId),
    ];
  }

  void _nextPage() {
    if (_currentIndex < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to dashboard after completion
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.fitness_center, size: 24),
            const SizedBox(width: 8),
            Text('Getting You Gym-Ready! 💪',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary,
                    )),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 4,
        automaticallyImplyLeading: false,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _steps.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Progress Bar
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: LinearProgressIndicator(
                    key: ValueKey(_currentIndex),
                    value: (_currentIndex + 1) / _steps.length,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 24),

                // Onboarding Step Content
                Expanded(child: _steps[index]),

                // Navigation Buttons
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Row(
                    key: ValueKey(_currentIndex),
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentIndex > 0)
                        TextButton.icon(
                          onPressed: _prevPage,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _nextPage,
                        icon: Icon(_currentIndex == _steps.length - 1 ? Icons.check : Icons.arrow_forward),
                        label: Text(_currentIndex == _steps.length - 1 ? 'Finish' : 'Next'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}