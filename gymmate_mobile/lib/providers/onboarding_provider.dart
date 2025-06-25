import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OnboardingProvider with ChangeNotifier {
  double height = 0;
  double weight = 0;
  int age = 0;
  String? gender;
  List<String> fitnessGoals = [];
  Map<String, dynamic> dietPreferences = {};
  Map<String, dynamic> workoutHabits = {};
  Map<String, dynamic> firstChallenge = {};

  void setHeight(double h) {
    height = h;
    notifyListeners();
  }

  void setWeight(double w) {
    weight = w;
    notifyListeners();
  }

  void setAge(int a) {
    age = a;
    notifyListeners();
  }

  void setGender(String g) {
    gender = g;
    notifyListeners();
  }

  void toggleFitnessGoal(String goal) {
    if (fitnessGoals.contains(goal)) {
      fitnessGoals.remove(goal);
    } else {
      fitnessGoals.add(goal);
    }
    notifyListeners();
  }

  void setDietPreferences(Map<String, dynamic> prefs) {
    dietPreferences = prefs;
    notifyListeners();
  }

  void setWorkoutHabits(Map<String, dynamic> habits) {
    workoutHabits = habits;
    notifyListeners();
  }

  void setFirstChallenge(Map<String, dynamic> challenge) {
    firstChallenge = challenge;
    notifyListeners();
  }

  Future<bool> completeOnboarding(String token) async {
    final url = Uri.parse('http://localhost:5050/api/onboarding/complete');
    final body = {
      "profile": {
        "height": height,
        "weight": weight,
        "age": age,
        "gender": gender,
      },
      "fitnessGoals": fitnessGoals,
      "dietPreferences": dietPreferences,
      "workoutHabits": workoutHabits,
      "firstChallenge": firstChallenge,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print('❌ Backend onboarding failed: ${response.body}');
      return false;
    }
  }
}