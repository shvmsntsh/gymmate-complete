import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'fitness_goal_step.dart';

class ProfileStep extends StatefulWidget {
  final String userId;
  const ProfileStep({Key? key, required this.userId}) : super(key: key);
  const ProfileStep({Key? key}) : super(key: key);

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  final _formKey = GlobalKey<FormState>();
  String? name, gender;
  int? age;
  double? height, weight;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AnimatedOpacity(
            opacity: 1.0,
            duration: const Duration(milliseconds: 800),
            child: Card(
              color: Colors.grey.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: 0.2,
                        backgroundColor: Colors.grey.shade800,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "🧍‍♂️ Set Up Your Hero Profile",
                        style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person, color: Colors.white),
                          labelText: "Name",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => name = val,
                        validator: (val) => val == null || val.isEmpty ? "Enter your name" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.cake, color: Colors.white),
                          labelText: "Age",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => age = int.tryParse(val ?? ''),
                        validator: (val) => val == null || val.isEmpty ? "Enter age" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.wc, color: Colors.white),
                          labelText: "Gender",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        dropdownColor: Colors.black,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: "Male", child: Text("Male")),
                          DropdownMenuItem(value: "Female", child: Text("Female")),
                          DropdownMenuItem(value: "Other", child: Text("Other")),
                        ],
                        onChanged: (val) => setState(() => gender = val),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.height, color: Colors.white),
                          labelText: "Height (cm)",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => height = double.tryParse(val ?? ''),
                        validator: (val) => val == null || val.isEmpty ? "Enter height" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.monitor_weight, color: Colors.white),
                          labelText: "Weight (kg)",
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onSaved: (val) => weight = double.tryParse(val ?? ''),
                        validator: (val) => val == null || val.isEmpty ? "Enter weight" : null,
                      ),
                      const Spacer(),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          ),
                          onPressed: () async {
                            if (_formKey.currentState?.validate() ?? false) {
                              _formKey.currentState?.save();
                              final profileData = {
                                'name': name,
                                'age': age,
                                'gender': gender,
                                'height': height,
                                'weight': weight,
                              };

                              const apiUrl = 'http://shivams-mac-mini-m1.local:5050/api/gym/update-profile';

                              try {
                                final response = await http.put(
                                  Uri.parse(apiUrl),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode(profileData),
                                );
                                if (response.statusCode == 200) {
                                  print("✅ Profile updated successfully");
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const FitnessGoalStepPage()),
                                  );
                                } else {
                                  print("❌ Failed to update profile: ${response.body}");
                                }
                              } catch (e) {
                                print("❌ Error: $e");
                              }
                            }
                          },
                          child: const Text("Continue your journey →", style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
