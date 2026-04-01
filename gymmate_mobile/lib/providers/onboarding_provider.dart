import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

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

  void loadFromProgress(Map<String, dynamic> progress) {
    final profile = progress['profile'] ?? {};
    height = (profile['height'] ?? 0).toDouble();
    weight = (profile['weight'] ?? 0).toDouble();
    age = profile['age'] ?? 0;
    gender = profile['gender'];
    fitnessGoals = List<String>.from(progress['fitnessGoals'] ?? []);

    // Handle diet preferences
    if (progress['dietPreferences'] != null) {
      dietPreferences = Map<String, dynamic>.from(progress['dietPreferences']);
    } else {
      dietPreferences = {
        'type': 'flexible',
        'allergies': [],
        'dailyMeals': 3,
        'waterIntake': 8,
        'restrictions': [],
      };
    }

    // Handle workout habits/preferences
    if (progress['workoutHabits'] != null) {
      workoutHabits = Map<String, dynamic>.from(progress['workoutHabits']);
    } else if (progress['workoutPreferences'] != null) {
      workoutHabits = Map<String, dynamic>.from(progress['workoutPreferences']);
    } else {
      workoutHabits = {
        'preferredTime': 'flexible',
        'favoriteExercises': [],
        'currentActivityLevel': 'moderate',
        'workoutsPerWeek': 3,
        'sessionDuration': 60,
        'hasInjuries': false,
        'injuryDetails': null,
      };
    }

    // Handle first challenge
    if (progress['firstChallenge'] != null) {
      firstChallenge = Map<String, dynamic>.from(progress['firstChallenge']);
    } else {
      firstChallenge = {
        'isAccepted': false,
        'type': '7_day_checkin',
        'startDate': null,
        'endDate': null,
        'progress': 0,
        'isCompleted': false,
        'completedAt': null,
      };
    }

    notifyListeners();
  }

  Future<bool> completeOnboarding(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/onboarding/complete');
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
      return false;
    }
  }
}
