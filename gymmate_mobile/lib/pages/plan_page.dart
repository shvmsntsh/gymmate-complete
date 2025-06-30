import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({Key? key}) : super(key: key);

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userData;
  List<dynamic>? _workoutPlan;
  List<dynamic>? _mealPlan;
  double? _bmi;

  @override
  void initState() {
    super.initState();
    _fetchDataAndGeneratePlan();
  }

  Future<void> _fetchDataAndGeneratePlan() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/user-details-for-plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load user data');
      }
      
      final userData = json.decode(response.body);
      _userData = userData;

      final double weight = (_userData?['profile']?['weight'] as num?)?.toDouble() ?? 0.0;
      final double height = (_userData?['profile']?['height'] as num?)?.toDouble() ?? 0.0;
      if (weight > 0 && height > 0) {
        _bmi = weight / ((height / 100) * (height / 100));
      }

      final aiService = AiService();
      final planData = {
        'age': _userData?['profile']?['age'],
        'gender': _userData?['profile']?['gender'],
        'weight': _userData?['profile']?['weight'],
        'height': _userData?['profile']?['height'],
        'fitnessGoals': _userData?['fitnessGoals'],
        'dietPreferences': _userData?['dietPreferences'],
        'workoutsPerWeek': _userData?['workoutHabits']?['workoutsPerWeek'],
      };
      
      final generatedPlan = await aiService.generatePlan(
        userData: planData,
        token: token,
      );

      if (mounted) {
        setState(() {
          _workoutPlan = generatedPlan['workoutPlan'];
          _mealPlan = generatedPlan['mealPlan'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBMICard(),
                      const SizedBox(height: 24),
                      _buildMealPlanCard(),
                      const SizedBox(height: 24),
                      _buildWorkoutPlanCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBMICard() {
    final weight = (_userData?['profile']?['weight'] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weight', style: TextStyle(fontSize: 16)),
                Text('${weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
             if (_bmi != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BMI', style: TextStyle(fontSize: 16)),
                  Text(
                    '${_bmi!.toStringAsFixed(1)} (${_getBMICategory(_bmi!)})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealPlanCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_dining, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                const Text("Your Meal Plan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_mealPlan != null)
              ..._mealPlan!.map((item) {
                final mealName = item['name'] ?? 'Meal';
                final description = item['description'] ?? 'No description';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• $mealName: ', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Expanded(child: Text(description, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutPlanCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                const Text("Your Workout Plan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_workoutPlan != null)
              ..._workoutPlan!.map((item) {
                String workoutText = item['name'] ?? 'Workout';

                if(item.containsKey('exercise')) {
                  workoutText += ': ${item['exercise']}';
                }
                if(item.containsKey('sets')) {
                  workoutText += ' - ${item['sets']} sets';
                }
                if(item.containsKey('reps')) {
                  workoutText += ' of ${item['reps']} reps';
                }
                if(item.containsKey('duration')) {
                  workoutText += ' - ${item['duration']} min';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(workoutText, style: const TextStyle(fontSize: 16))),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
} 