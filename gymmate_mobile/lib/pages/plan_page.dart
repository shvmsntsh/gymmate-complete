import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'package:intl/intl.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({Key? key}) : super(key: key);

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userData;
  List<dynamic>? _weekPlan;
  double? _bmi;

  // Checklist state: Set of 'day-mealType' and 'day-workout' keys
  Set<String> _checkedItems = {};

  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _authProvider?.addListener(_onAuthChanged);
    _fetchDataAndGeneratePlan();
  }

  void _onAuthChanged() {
    if (_authProvider != null && !_authProvider!.isAuth) {
      setState(() {
        _weekPlan = null;
        _checkedItems.clear();
        _userData = null;
        _bmi = null;
        _isLoading = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _fetchDataAndGeneratePlan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = _authProvider?.token;
      if (token == null) {
        setState(() {
          _error = 'Not authenticated.';
          _isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/user-details-for-plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Failed to load user data.';
          _isLoading = false;
        });
        return;
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
        if (generatedPlan['weekPlan'] == null) {
          setState(() {
            _error = 'AI could not generate a plan. Please try again later.';
            _isLoading = false;
          });
          return;
        }
        setState(() {
          // Defensive parsing: always convert weekPlan to a List in correct order
          final dynamic rawWeekPlan = generatedPlan['weekPlan'];
          final List<String> daysOfWeek = [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
          ];
          if (rawWeekPlan is List) {
            _weekPlan = rawWeekPlan;
          } else if (rawWeekPlan is Map) {
            // Convert map to list in correct order, fallback for missing days
            _weekPlan = daysOfWeek.map((day) => rawWeekPlan[day] ?? {'day': day, 'meal': {}, 'workout': {}}).toList();
          } else {
            _weekPlan = [];
          }
          print('DEBUG: _weekPlan =\n${_weekPlan.toString()}');
          _isLoading = false;
          _checkedItems.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not generate plan. Please try again later.';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate Plan',
            onPressed: _isLoading ? null : _fetchDataAndGeneratePlan,
          ),
        ],
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
                      _buildChecklistWeekPlan(),
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

  Widget _buildChecklistWeekPlan() {
    if (_weekPlan == null) return const SizedBox.shrink();
    if (_weekPlan!.length != 7) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Sorry, your plan could not be loaded. Please try regenerating.',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    final today = DateFormat('EEEE').format(DateTime.now());
    return Column(
      children: _weekPlan!
          .where((item) => item != null && item is Map && item['day'] != null)
          .map((item) {
        final day = item is Map && item['day'] != null ? item['day'] : '';
        final meal = item is Map && item['meal'] is Map ? item['meal'] : {};
        final workout = item is Map && item['workout'] is Map ? item['workout'] : {};
        final isToday = day == today;
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: isToday ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
          child: ExpansionTile(
            title: Text(day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                )),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...['breakfast', 'lunch', 'snack', 'dinner'].map((mealType) {
                      final mealDesc = meal[mealType];
                      if (mealDesc == null || mealDesc is! Map) return const SizedBox.shrink();
                      String label = mealType[0].toUpperCase() + mealType.substring(1);
                      String key = '$day-meal-$mealType';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            value: _checkedItems.contains(key),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _checkedItems.add(key);
                                } else {
                                  _checkedItems.remove(key);
                                }
                              });
                            },
                            title: Text('$label'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.only(left: 0, right: 8),
                          ),
                          if (mealDesc['items'] != null && mealDesc['items'] is List)
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0, bottom: 2.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...List<String>.from(mealDesc['items'].whereType<String>()).map((item) => Text('• $item', style: const TextStyle(fontSize: 15))),
                                ],
                              ),
                            ),
                          if (mealDesc['macros'] != null && mealDesc['macros'] is Map)
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0, bottom: 2.0),
                              child: Text('Macros: ' +
                                  [
                                    if (mealDesc['macros']['calories'] != null) 'Cal: ${mealDesc['macros']['calories']}',
                                    if (mealDesc['macros']['protein'] != null) 'P: ${mealDesc['macros']['protein']}g',
                                    if (mealDesc['macros']['carbs'] != null) 'C: ${mealDesc['macros']['carbs']}g',
                                    if (mealDesc['macros']['fat'] != null) 'F: ${mealDesc['macros']['fat']}g',
                                  ].join(' | '),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ),
                          if (mealDesc['micros'] != null && mealDesc['micros'] is Map)
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                              child: Text('Micros: ' +
                                  mealDesc['micros'].entries.map((e) => '${e.key}: ${e.value}').join(' | '),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
                            ),
                        ],
                      );
                    }),
                    if (workout.isNotEmpty) const Divider(),
                    if (workout['target'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                        child: Text('Target: ${workout['target']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    if (workout['exercises'] != null && workout['exercises'] is List)
                      ...List<Map<String, dynamic>>.from(
                        workout['exercises'].whereType<Map<String, dynamic>>()
                      ).asMap().entries.map((entry) {
                        final i = entry.key;
                        final w = entry.value;
                        String key = '$day-workout-$i';
                        String label = '${w['name'] ?? ''}';
                        if (w['sets'] != null && w['reps'] != null) {
                          label += ' (${w['sets']}x${w['reps']})';
                        }
                        return CheckboxListTile(
                          value: _checkedItems.contains(key),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _checkedItems.add(key);
                              } else {
                                _checkedItems.remove(key);
                              }
                            });
                          },
                          title: Text(label),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.only(left: 0, right: 8),
                        );
                      }),
                    if (workout['durationMinutes'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text('Duration: ${workout['durationMinutes']} min', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
} 