import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:step_progress_indicator/step_progress_indicator.dart';
import '../../providers/onboarding_provider.dart';
import 'steps/welcome_step.dart';
import 'steps/profile_step.dart';
import 'steps/goals_step.dart';
import 'steps/diet_step.dart';
import 'steps/workout_step.dart';
import 'steps/challenge_step.dart';
import 'steps/completion_step.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<OnboardingProvider>();
    _pageController = PageController(initialPage: provider.currentStep - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.initialize();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<OnboardingProvider>(
        builder: (context, provider, child) {
          if (_pageController.hasClients &&
              _pageController.page?.round() != provider.currentStep - 1) {
            _pageController.animateToPage(
              provider.currentStep - 1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }

          return Stack(
            children: [
              Column(
                children: [
                  _buildCustomAppBar(provider),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _buildStepPages(),
                    ),
                  ),
                ],
              ),
              if (provider.isLoading) _buildLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomAppBar(OnboardingProvider provider) {
    // This is a simplified app bar.
    // The previous one had too many dependencies on the old provider.
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
      color: Theme.of(context).primaryColor,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (provider.currentStep > 1)
                IconButton(
                  onPressed: provider.previousStep,
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
              const Spacer(),
              Text(
                'Step ${provider.currentStep} of 7', // Hardcoded total steps
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              if (provider.currentStep > 1) const SizedBox(width: 48) // balance the back button
            ],
          ),
          const SizedBox(height: 10),
          StepProgressIndicator(
            totalSteps: 7, // Hardcoded
            currentStep: provider.currentStep,
            size: 8,
            padding: 0,
            selectedColor: Colors.amber,
            unselectedColor: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStepPages() {
    final provider = Provider.of<OnboardingProvider>(context, listen: false);
    final userId = provider.userId;
    final token = provider.token;
    return [
      const WelcomeStep(),
      const ProfileStep(),
      const GoalsStep(),
      DietStep(userId: userId ?? '', token: token ?? ''),
      WorkoutStep(userId: userId ?? '', token: token ?? ''),
      const ChallengeStep(),
      const CompletionStep(),
    ];
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}