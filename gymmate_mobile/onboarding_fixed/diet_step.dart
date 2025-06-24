import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../utils/auth_service.dart';
import 'workout_step.dart';

class DietStepPage extends StatefulWidget {
  final String userId;
  final String userId;

  const DietStepPage({super.key, required this.token, required this.userId});

  @override
  State<DietStepPage> createState() => _DietStepPageState();
}

class _DietStepPageState extends State<DietStepPage> {
  String? _selectedDiet;

  final List<String> _dietOptions = [
    'High Protein',
    'Balanced',
    'Low Carb',
    'Vegetarian',
    'Vegan'
  ];

  Future<void> _submitDiet() async {
    if (_selectedDiet == null) {
      print("⚠️ No diet selected.");
      return;
    }

    print("📤 Submitting diet selection: $_selectedDiet");

    final url = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/gym/update/${widget.userId}');
    try {
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'diet': _selectedDiet}),
      );

      print("📬 Response status: ${response.statusCode}");
      print("📬 Response body: ${response.body}");

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkoutStepPage(
              token: widget.token,
              userId: widget.userId,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save diet. Try again.')),
        );
      }
    } catch (e) {
      print("❌ Error submitting diet: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting diet.')),
      );
    }
  }

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'DietStepPage(token: ${widget.token}, userId: ${widget.userId})';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text("Step 3: Diet"),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "What’s your diet preference?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _dietOptions.map((diet) {
                final isSelected = _selectedDiet == diet;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDiet = diet;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [Colors.orangeAccent, Colors.deepOrange],
                            )
                          : LinearGradient(
                              colors: [Colors.grey.shade200, Colors.grey.shade300],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? Colors.orange.withOpacity(0.4) : Colors.black12,
                          offset: const Offset(0, 4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: isSelected
                              ? Icon(Icons.check_circle, color: Colors.white, key: ValueKey("selected"))
                              : Icon(Icons.radio_button_unchecked, color: Colors.black54, key: ValueKey("unselected")),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          diet,
                          style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _submitDiet,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
