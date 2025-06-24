import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoalsStepPage extends StatefulWidget {
  final String userId;
  final VoidCallback onNext;

  const GoalsStepPage({Key? key, required this.userId, required this.onNext}) : super(key: key);

  @override
  _GoalsStepPageState createState() => _GoalsStepPageState();
}

class _GoalsStepPageState extends State<GoalsStepPage> with SingleTickerProviderStateMixin {
  List<String> goals = ['Lose Weight', 'Build Muscle', 'Improve Stamina', 'Stay Fit'];
  List<String> selectedGoals = [];
  late AnimationController _controller;
  late Animation<double> _animation;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggleGoal(String goal) {
    setState(() {
      if (selectedGoals.contains(goal)) {
        selectedGoals.remove(goal);
      } else {
        selectedGoals.add(goal);
      }
    });
  }

  Future<void> submitGoals() async {
    if (selectedGoals.isEmpty) return;

    setState(() => isLoading = true);

    print('📤 Submitting fitness goals: ${selectedGoals.join(', ')} for userId: ${widget.userId}');

    final response = await http.post(
      Uri.parse('http://shivams-mac-mini-m1.local:5050/api/gym/update-goals'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': widget.userId,
        'fitnessGoals': selectedGoals,
      }),
    );

    print('📬 Server response: ${response.statusCode}, Body: ${response.body}');

    setState(() => isLoading = false);

    if (response.statusCode == 200) {
      widget.onNext();
    } else {
      String errorMessage = 'Failed to save goals';
      try {
        final errorResponse = json.decode(response.body);
        if (errorResponse['message'] != null) {
          errorMessage = errorResponse['message'];
        }
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏆 Choose Your Fitness Goals',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: goals.map((goal) {
                  final isSelected = selectedGoals.contains(goal);
                  return GestureDetector(
                    onTap: () => toggleGoal(goal),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.greenAccent : Colors.grey[800],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.fitness_center,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(goal, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: isLoading ? null : submitGoals,
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ),
    );
  }
}