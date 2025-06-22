import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorkoutStep extends StatefulWidget {
  final String userId;

  const WorkoutStep({super.key, required this.userId});

  @override
  State<WorkoutStep> createState() => _WorkoutStepState();
}

class _WorkoutStepState extends State<WorkoutStep> with TickerProviderStateMixin {
  final List<String> workoutOptions = [
    'Strength Training',
    'Cardio',
    'Yoga',
    'HIIT',
    'CrossFit',
    'Pilates',
    'Martial Arts'
  ];
  List<String> selectedWorkouts = [];
  bool isSaving = false;

  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeInAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveWorkouts() async {
    setState(() {
      isSaving = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final url = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/gym/update/${widget.userId}');
    Map<String, dynamic> bodyData = {};
    if (selectedWorkouts.isNotEmpty) {
      bodyData['workout'] = selectedWorkouts.first;
    }

    debugPrint("📤 Submitting workout data: $bodyData");

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(bodyData),
    );

    debugPrint("📬 Received response: ${response.statusCode} ${response.body}");

    if (response.statusCode == 200) {
      Navigator.pushNamed(context, '/onboarding/goals/${widget.userId}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save workouts')),
      );
    }

    setState(() {
      isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Your Workout Style"),
          backgroundColor: Colors.deepPurple,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.fitness_center, color: Colors.deepPurple, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Workout Preferences",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Select all that apply. We'll tailor suggestions accordingly.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: workoutOptions.map((option) {
                  final isSelected = selectedWorkouts.contains(option);
                  IconData icon;
                  switch (option) {
                    case 'Strength Training':
                      icon = Icons.fitness_center;
                      break;
                    case 'Cardio':
                      icon = Icons.directions_run;
                      break;
                    case 'Yoga':
                      icon = Icons.self_improvement;
                      break;
                    case 'HIIT':
                      icon = Icons.flash_on;
                      break;
                    case 'CrossFit':
                      icon = Icons.sports_handball;
                      break;
                    case 'Pilates':
                      icon = Icons.accessibility_new;
                      break;
                    case 'Martial Arts':
                      icon = Icons.sports_mma;
                      break;
                    default:
                      icon = Icons.fitness_center;
                  }

                  return ChoiceChip(
                    avatar: Icon(icon, color: isSelected ? Colors.white : Colors.deepPurple),
                    label: Text(option),
                    selected: isSelected,
                    selectedColor: Colors.deepPurpleAccent,
                    backgroundColor: Colors.grey[200],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedWorkouts.add(option);
                        } else {
                          selectedWorkouts.remove(option);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveWorkouts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Next", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}