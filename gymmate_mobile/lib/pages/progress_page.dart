import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/onboarding_service.dart';
import '../providers/auth_provider.dart';
import '../pages/onboarding/onboarding_flow.dart';
import '../providers/onboarding_provider.dart';
import 'dart:convert';

class ProgressPage extends StatefulWidget {
  const ProgressPage({Key? key}) : super(key: key);

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  Map<String, dynamic>? _progressData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) throw Exception('No authentication token available');
      
      final service = OnboardingService();
      service.setToken(token);
      final data = await service.getUserProgress();
      
      print('🔍 Progress Data: ${jsonEncode(data)}');
      
      setState(() {
        _progressData = data;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error fetching progress: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _editOnboarding() {
    final provider = Provider.of<OnboardingProvider>(context, listen: false);
    if (_progressData != null) {
      print('[ProgressPage] Passing dietPreferences to provider: ${_progressData!['dietPreferences']}');
      provider.loadFromProgress(_progressData!);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingFlow()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProgress,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_progressData == null) {
      return const Center(child: Text('No progress data found.'));
    }

    print('🔄 Building Progress Page with data: ${jsonEncode(_progressData)}');

    final profile = (_progressData!['profile'] is Map)
        ? Map<String, dynamic>.from(_progressData!['profile'])
        : <String, dynamic>{};
    final fitnessGoals = _progressData!['fitnessGoals'] is List
        ? List<String>.from(_progressData!['fitnessGoals'])
        : <String>[];
    final dietPreferences = (_progressData!['dietPreferences'] is Map)
        ? Map<String, dynamic>.from(_progressData!['dietPreferences'])
        : <String, dynamic>{};
    final workoutHabits = (_progressData!['workoutHabits'] is Map)
        ? Map<String, dynamic>.from(_progressData!['workoutHabits'])
        : <String, dynamic>{};
    final challenge = (_progressData!['firstChallenge'] is Map)
        ? Map<String, dynamic>.from(_progressData!['firstChallenge'])
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editOnboarding,
            tooltip: 'Edit Onboarding',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Profile', _buildValueWidget(_formatProfile(profile))),
          const SizedBox(height: 16),
          _buildSection('Fitness Goals', _buildValueWidget(_formatFitnessGoals(fitnessGoals))),
          const SizedBox(height: 16),
          _buildSection('Diet Preferences', _buildValueWidget(_formatDietPreferences(dietPreferences))),
          const SizedBox(height: 16),
          _buildSection('Workout Preferences', _buildValueWidget(_formatWorkoutHabits(workoutHabits))),
          const SizedBox(height: 16),
          _buildSection('Challenge', _buildValueWidget(_formatChallenge(challenge))),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Card(
      elevation: 2,
      color: const Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _formatProfile(Map<String, dynamic> profile) {
    return {
      'Age': profile['age']?.toString() ?? '-',
      'Gender': profile['gender']?.toString().toUpperCase() ?? '-',
      'Weight': '${profile['weight']?.toString() ?? '-'} kg',
      'Height': '${profile['height']?.toString() ?? '-'} cm',
    };
  }

  List<String> _formatFitnessGoals(List<String> goals) {
    return goals.map((goal) => goal.replaceAll('_', ' ').toUpperCase()).toList();
  }

  Map<String, dynamic> _formatDietPreferences(Map<String, dynamic> prefs) {
    print('🥗 Diet Preferences Data: ${jsonEncode(prefs)}');
    
    final allergies = (prefs['allergies'] as List?)?.map((e) => e.toString().toUpperCase()).toList() ?? [];
    final restrictions = (prefs['restrictions'] as List?)?.map((e) => e.toString().toUpperCase()).toList() ?? [];
    
    return {
      'Diet Type': prefs['type']?.toString().replaceAll('_', ' ').toUpperCase() ?? '-',
      'Daily Meals': prefs['dailyMeals']?.toString() ?? '-',
      'Water Intake': '${prefs['waterIntake']?.toString() ?? '-'} glasses',
      'Allergies': allergies.isEmpty ? 'None' : allergies.join(', '),
      'Restrictions': restrictions.isEmpty ? 'None' : restrictions.join(', '),
    };
  }

  Map<String, dynamic> _formatWorkoutHabits(Map<String, dynamic> habits) {
    print('🏋️ Workout Habits Data: ${jsonEncode(habits)}');
    
    final favoriteExercises = (habits['favoriteExercises'] as List?)
        ?.map((e) => e.toString().replaceAll('_', ' ').toUpperCase())
        .toList() ?? [];
    
    return {
      'Preferred Time': habits['preferredTime']?.toString().replaceAll('_', ' ').toUpperCase() ?? '-',
      'Activity Level': habits['currentActivityLevel']?.toString().replaceAll('_', ' ').toUpperCase() ?? '-',
      'Workouts Per Week': habits['workoutsPerWeek']?.toString() ?? '-',
      'Session Duration': '${habits['sessionDuration']?.toString() ?? '-'} minutes',
      'Favorite Exercises': favoriteExercises.isEmpty ? '-' : favoriteExercises.join(', '),
      'Has Injuries': habits['hasInjuries'] == true ? 'Yes' : 'No',
    };
  }

  Map<String, dynamic> _formatChallenge(Map<String, dynamic> challenge) {
    print('🎯 Challenge Data: ${jsonEncode(challenge)}');
    
    if (challenge.isEmpty || !challenge['isAccepted'] || challenge['type'] == null) {
      return {'Status': 'No active challenge'};
    }

    return {
      'Type': challenge['type'].toString().replaceAll('_', ' ').toUpperCase(),
      'Status': challenge['isCompleted'] == true ? 'COMPLETED' : 'IN PROGRESS',
      'Progress': '${challenge['progress']?.toString() ?? '0'}%',
      'Start Date': challenge['startDate'] != null 
          ? DateTime.parse(challenge['startDate']).toString().split('.')[0] 
          : '-',
    };
  }

  Widget _buildValueWidget(dynamic value) {
    if (value == null) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    } else if (value is Map) {
      if (value.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.entries.map<Widget>((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key.toString().replaceAll('_', ' '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } else if (value is List) {
      if (value.isEmpty) return const Text('-', style: TextStyle(color: Colors.grey));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map<Widget>((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              Expanded(
                child: Text(
                  item.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        )).toList(),
      );
    } else {
      return Text(
        value.toString(),
        style: const TextStyle(color: Colors.white),
      );
    }
  }
} 