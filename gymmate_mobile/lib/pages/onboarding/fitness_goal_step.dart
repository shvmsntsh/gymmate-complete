import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FitnessGoalStep extends StatefulWidget {
  final String userId;
  const FitnessGoalStep({Key? key, required this.userId}) : super(key: key);

  @override
  State<FitnessGoalStep> createState() => _FitnessGoalStepState();
}

class _FitnessGoalStepState extends State<FitnessGoalStep> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String? _selectedGoal;

  final List<Map<String, dynamic>> goals = [
    {"label": "Lose Weight", "icon": Icons.scale},
    {"label": "Build Muscle", "icon": Icons.fitness_center},
    {"label": "Improve Endurance", "icon": Icons.directions_run},
    {"label": "Stay Healthy", "icon": Icons.favorite},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectGoal(String label) {
    setState(() {
      _selectedGoal = label;
    });
  }

  void _submitGoal() {
    if (_selectedGoal != null) {
      print('✅ Selected fitness goal: $_selectedGoal');
      Navigator.pushNamed(
        context,
        '/onboarding/completion',
        arguments: {
          'goal': _selectedGoal,
          'userId': ModalRoute.of(context)!.settings.arguments != null
              ? (ModalRoute.of(context)!.settings.arguments as Map)['userId']
              : null,
        },
      );
    } else {
      print('⚠️ No fitness goal selected.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🎯 What's your goal?",
                  style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text("Choose a fitness direction so we can tailor your journey.",
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              Expanded(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      final isSelected = _selectedGoal == goal["label"];
                      return FadeTransition(
                        opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
                          parent: _controller,
                          curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
                        )),
                        child: GestureDetector(
                          onTap: () => _selectGoal(goal["label"]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(goal["icon"], size: 28),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    goal["label"],
                                    style: GoogleFonts.poppins(fontSize: 18),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _selectedGoal != null ? _submitGoal : null,
                  child: const Text("Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}