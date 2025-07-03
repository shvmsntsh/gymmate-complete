import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

void logPlanPage(String msg) {
  assert(() {
    debugPrint(msg);
    return true;
  }());
}

// Place these at the very top-level, before any class
class AnimatedFillIcon extends StatelessWidget {
  final IconData icon;
  final double percent;
  final Color color;
  final double size;
  const AnimatedFillIcon({required this.icon, required this.percent, required this.color, this.size = 40, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percent.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: color.withOpacity(0.12), size: size),
            ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: Icon(icon, color: color, size: size),
              ),
            ),
          ],
        );
      },
    );
  }
}

Widget macroSummary(String label, dynamic val, dynamic goal, Color color) {
  final double dVal = (val is int) ? val.toDouble() : (val is double ? val : double.tryParse(val.toString()) ?? 0.0);
  final double dGoal = (goal is int) ? goal.toDouble() : (goal is double ? goal : double.tryParse(goal.toString()) ?? 0.0);
  final percent = dGoal > 0 ? (dVal / dGoal * 100).clamp(0, 100) : 0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label • ${percent.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      Text('${dVal.toStringAsFixed(0)} / ${dGoal.toStringAsFixed(0)} g', style: const TextStyle(fontSize: 13)),
    ],
  );
}

// Place parseExercise at the top-level, outside any class, with correct Dart syntax
Map<String, dynamic> parseExercise(dynamic ex) {
  if (ex is Map<String, dynamic>) return ex;
  if (ex is String) {
    final match = RegExp(r'^(.*)\s*\((\d+)x(\d+)(?:,\s*rest\s*(\d+)s?)?\)?$').firstMatch(ex);
    if (match != null) {
      return {
        'name': match.group(1)?.trim() ?? ex,
        'sets': int.tryParse(match.group(2) ?? '') ?? 3,
        'reps': int.tryParse(match.group(3) ?? '') ?? 12,
        'rest': int.tryParse(match.group(4) ?? '') ?? 60,
      };
    }
    return {'name': ex, 'sets': 3, 'reps': 12, 'rest': 60};
  }
  return {'name': 'Exercise', 'sets': 3, 'reps': 12, 'rest': 60};
}

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

  // 1. Store the current day's plan only
  Map<String, dynamic>? _dayPlan;
  bool _usedFallback = false;
  String? _aiError;

  int _selectedDayIndex = DateTime.now().weekday - 1; // 0=Monday

  int get _todayIndex => DateTime.now().weekday - 1;

  // 1. Add loading animation and animated text sequence
  List<String> _loadingMessages = [
    '🧠 Generating your personalized fitness plan…',
    '🏋️‍♂️ Matching workouts to your goals…',
    '🥗 Balancing meals just for you…',
  ];
  int _loadingMessageIndex = 0;

  // 2. Use cached AI response if onboarding data hasn't changed
  Map<String, dynamic>? _lastUserData;
  Map<String, dynamic>? _cachedDayPlan;

  Map<String, bool> _checkboxState = {};

  Map<String, dynamic>? _plan; // Store the full plan object from backend
  bool _planLoading = true;
  bool _planError = false;

  // Add state for meal logging
  Map<String, Map<int, double>> _mealItemQuantities = {}; // key: mealType, value: {itemIdx: quantity}
  double _totalCaloriesLogged = 0;

  // Add state for daily macro goals (for demo, use static or calculate from plan if available)
  final double dailyCalGoal = 1800;
  final double dailyPGoal = 120;
  final double dailyFGoal = 60;
  final double dailyCGoal = 220;

  // Add state for workout logging
  List<bool> _workoutCompleted = [];

  int _waterGlasses = 0;
  final int _waterGoal = 8; // 8 glasses per day

  // Add state for steps
  int _steps = 0;
  int _stepGoal = 8000; // Example, can be set from onboarding

  Map<String, bool> _exerciseCompleted = {}; // key: exerciseKey, value: checked

  double? _calorieGoal;

  // Helper to get calories for a meal item (assume per serving if not specified)
  double _getCaloriesForMealItem(Map meal, double quantity) {
    // If meal['cal'] is total for all items, divide equally
    if (meal['cal'] != null && meal['items'] is List && meal['items'].length > 0) {
      return (meal['cal'] / meal['items'].length) * quantity;
    }
    return 0;
  }

  // Helper to get macros for a meal item (divide meal macros equally)
  Map<String, double> _getMacrosForMealItem(Map meal, double quantity) {
    final macros = {'p': 0.0, 'f': 0.0, 'c': 0.0};
    if (meal['p'] != null && meal['items'] is List && meal['items'].length > 0) macros['p'] = (meal['p'] / meal['items'].length) * quantity;
    if (meal['f'] != null && meal['items'] is List && meal['items'].length > 0) macros['f'] = (meal['f'] / meal['items'].length) * quantity;
    if (meal['c'] != null && meal['items'] is List && meal['items'].length > 0) macros['c'] = (meal['c'] / meal['items'].length) * quantity;
    return macros;
  }

  // Calculate daily totals
  Map<String, double> _calculateDailyTotals(Map<String, dynamic> plan) {
    double cal = 0, p = 0, f = 0, c = 0;
    final mealsRaw = plan['meals'];
    logPlanPage('[PlanPage] _calculateDailyTotals: plan["meals"] type: \\${mealsRaw.runtimeType}, value: \\${mealsRaw}');
    final meals = mealsRaw is Map ? mealsRaw as Map : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      final mealRaw = meals[mealType];
      logPlanPage('[PlanPage] _calculateDailyTotals: meals[\\"$mealType\\"] type: \\${mealRaw.runtimeType}, value: \\${mealRaw}');
      final meal = mealRaw is Map ? mealRaw as Map : <String, dynamic>{};
      final items = meal['items'] is List ? meal['items'] : [];
      for (int i = 0; i < items.length; i++) {
        final key = '${plan['day']}-meal-$mealType-$i';
        if (_checkboxState[key] == true) {
          final qty = _mealItemQuantities[mealType]?[i] ?? 1.0;
          cal += _getCaloriesForMealItem(meal, qty);
          final macros = _getMacrosForMealItem(meal, qty);
          p += macros['p']!;
          f += macros['f']!;
          c += macros['c']!;
        }
      }
    }
    return {'cal': cal, 'p': p, 'f': f, 'c': c};
  }

  // Update _totalCaloriesLogged whenever a meal item is checked/quantity changed
  void _recalculateTotalCaloriesLogged(Map<String, dynamic> plan) {
    double total = 0;
    // Defensive: ensure meals is a Map
    final meals = plan['meals'] is Map ? plan['meals'] as Map : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      // Defensive: ensure meal is a Map
      final meal = meals[mealType] is Map ? meals[mealType] as Map : <String, dynamic>{};
      final items = meal['items'] is List ? meal['items'] : [];
      for (int i = 0; i < items.length; i++) {
        final key = '${plan['day']}-meal-$mealType-$i';
        if (_checkboxState[key] == true) {
          final qty = _mealItemQuantities[mealType]?[i] ?? 1.0;
          total += _getCaloriesForMealItem(meal, qty);
        }
      }
    }
    setState(() {
      _totalCaloriesLogged = total;
    });
  }

  // Helper to get workout calories (if available)
  double _getWorkoutCalories(Map workout) {
    return (workout['calories'] is num) ? workout['calories'].toDouble() : 0.0;
  }

  // Helper to get workout duration (if available)
  double _getWorkoutDuration(Map workout) {
    return (workout['duration'] is num) ? workout['duration'].toDouble() : 0.0;
  }

  // Calculate workout summary
  Map<String, dynamic> _calculateWorkoutSummary(Map<String, dynamic> plan) {
    final workoutRaw = plan['workout'];
    logPlanPage('[PlanPage] _calculateWorkoutSummary: plan["workout"] type: \\${workoutRaw.runtimeType}, value: \\${workoutRaw}');
    final workout = workoutRaw is Map ? workoutRaw as Map : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    logPlanPage('[PlanPage] _calculateWorkoutSummary: workout["exercises"] type: \\${exercisesRaw.runtimeType}, value: \\${exercisesRaw}');
    final exercises = (exercisesRaw is List) ? exercisesRaw.map(parseExercise).toList() : <Map<String, dynamic>>[];
    final exerciseKeys = List.generate(exercises.length, (i) => '${plan['day']}-workout-ex-$i');
    int completed = exerciseKeys.where((k) => _exerciseCompleted[k] == true).length;
    int total = exerciseKeys.length > 0 ? exerciseKeys.length : 1;
    final duration = _getWorkoutDuration(workout);
    final calories = _getWorkoutCalories(workout);
    return {
      'completed': completed,
      'total': total,
      'duration': duration * (completed / total),
      'calories': calories * (completed / total),
      'progress': total > 0 ? completed / total : 0.0,
    };
  }

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _authProvider?.addListener(_onAuthChanged);
    _loadUserDataAndBMI();
    _loadCheckboxState();
    _loadPlanIfNeeded();
    _updateCalorieGoal();
    // Animated loading message
    Future.doWhile(() async {
      if (!_planLoading) return false;
      await Future.delayed(const Duration(seconds: 2));
      if (_planLoading) {
        setState(() {
          _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
        });
      }
      return _planLoading;
    });
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
        _plan = null;
        _planLoading = false;
        _planError = false;
      });
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadUserDataAndBMI() async {
    final userData = _authProvider?.userData;
    if (userData != null) {
      setState(() {
        _userData = userData;
        final weight = (userData['profile']?['weight'] as num?)?.toDouble() ?? 0.0;
        final height = (userData['profile']?['height'] as num?)?.toDouble() ?? 0.0;
        if (weight > 0 && height > 0) {
          _bmi = weight / ((height / 100) * (height / 100));
        } else {
          _bmi = null;
        }
      });
    }
  }

  Future<void> _loadCheckboxState() async {
    final prefs = await SharedPreferences.getInstance();
    final map = prefs.getString('plan_checkbox_state');
    if (map != null) {
      setState(() {
        _checkboxState = Map<String, bool>.from(json.decode(map));
      });
    }
    final workoutMap = prefs.getString('plan_exercise_completed');
    if (workoutMap != null) {
      setState(() {
        _exerciseCompleted = Map<String, bool>.from(json.decode(workoutMap));
      });
    }
  }

  Future<void> _saveCheckboxState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('plan_checkbox_state', json.encode(_checkboxState));
    await prefs.setString('plan_exercise_completed', json.encode(_exerciseCompleted));
  }

  void _loadPlanIfNeeded() async {
    // Only fetch if plan is not loaded or onboarding changed or refresh is clicked
    final userData = _authProvider?.userData;
    if (userData == null) return;
    final onboardingHash = _getOnboardingHash(userData);
    final prefs = await SharedPreferences.getInstance();
    final cachedPlanStr = prefs.getString('cached_plan_$onboardingHash');
    if (cachedPlanStr != null) {
      try {
        final decoded = json.decode(cachedPlanStr);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            _plan = decoded;
            _planLoading = false;
            _planError = false;
          });
          return;
        } else {
          // Corrupted cache, clear and fetch fresh
          await prefs.remove('cached_plan_$onboardingHash');
        }
      } catch (e) {
        // Corrupted cache, clear and fetch fresh
        await prefs.remove('cached_plan_$onboardingHash');
      }
    }
    _fetchPlan(forceRefresh: false);
  }

  String _getOnboardingHash(Map<String, dynamic> userData) {
    final onboardingData = {
      'age': userData['profile']?['age'],
      'gender': userData['profile']?['gender'],
      'height': userData['profile']?['height'],
      'weight': userData['profile']?['weight'],
      'diet': userData['dietPreferences']?['type'],
      'goals': userData['fitnessGoals'],
      'activity': userData['workoutHabits']?['currentActivityLevel'],
      'frequency': userData['workoutHabits']?['daysPerWeek'],
    };
    return onboardingData.toString().hashCode.toString();
  }

  Future<void> _fetchPlan({bool forceRefresh = false}) async {
    setState(() {
      _planLoading = true;
      _planError = false;
      _usedFallback = false;
      _aiError = null;
    });
    try {
      final token = _authProvider?.token;
      if (token == null) {
        setState(() {
          _planError = true;
          _planLoading = false;
        });
        return;
      }
      final userData = _authProvider?.userData;
      final onboardingHash = _getOnboardingHash(userData!);
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/ai/generate-plan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({ 'forceRefresh': forceRefresh }),
      );
      if (response.statusCode != 200) {
        setState(() {
          _planError = true;
          _planLoading = false;
        });
        return;
      }
      final data = json.decode(response.body);
      setState(() {
        _plan = data['plan'];
        _usedFallback = data['_fallback'] == true;
        _aiError = data['_aiError'];
        _planLoading = false;
        _planError = false;
      });
      // Cache plan
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_plan_$onboardingHash', json.encode(_plan));
    } catch (e) {
      setState(() {
        _planError = true;
        _planLoading = false;
      });
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  void _incrementSteps([int by = 1000]) {
    setState(() {
      _steps = math.min(_steps + by, _stepGoal);
    });
  }
  void _decrementSteps([int by = 1000]) {
    setState(() {
      _steps = math.max(_steps - by, 0);
    });
  }

  // Helper for animated progress icon
  Widget animatedIcon({required IconData icon, required double percent, required Color color, double size = 32}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(icon, color: color.withOpacity(0.20), size: size),
        ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              stops: [0, 1 - percent, 1 - percent, 1],
              colors: [color, color, Colors.transparent, Colors.transparent],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: Icon(icon, color: color, size: size),
        ),
      ],
    );
  }

  void _updateCalorieGoal() {
    final userData = _authProvider?.userData;
    if (userData == null) return;
    final profile = userData['profile'] ?? {};
    final age = (profile['age'] as num?)?.toDouble() ?? 30;
    final gender = profile['gender'] ?? 'male';
    final weight = (profile['weight'] as num?)?.toDouble() ?? 70;
    final height = (profile['height'] as num?)?.toDouble() ?? 170;
    final activity = userData['workoutHabits']?['currentActivityLevel'] ?? 'sedentary';
    final goals = userData['fitnessGoals'] ?? [];
    // Mifflin-St Jeor BMR
    double bmr = gender == 'female'
        ? 10 * weight + 6.25 * height - 5 * age - 161
        : 10 * weight + 6.25 * height - 5 * age + 5;
    // Activity multiplier
    double activityMult = 1.2;
    if (activity == 'lightly_active') activityMult = 1.375;
    else if (activity == 'moderately_active') activityMult = 1.55;
    else if (activity == 'very_active') activityMult = 1.725;
    else if (activity == 'extra_active') activityMult = 1.9;
    double calGoal = bmr * activityMult;
    // Goal adjustment
    if (goals.contains('fat_loss')) calGoal -= 300;
    if (goals.contains('muscle_gain')) calGoal += 200;
    if (calGoal < 1200) calGoal = 1200;
    setState(() {
      _calorieGoal = calGoal.roundToDouble();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateCalorieGoal();
  }

  // Add a refresh button for user to force reload plan if needed
  void _refreshPlan() async {
    setState(() {
      _planLoading = true;
      _planError = false;
    });
    await _fetchPlan(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final colorScheme = Theme.of(context).colorScheme;
    // Defensive: check plan structure
    final hasMeals = plan != null && plan['meals'] is Map;
    final hasWorkout = plan != null && plan['workout'] is Map;
    final planReady = !_planLoading && !_planError && plan != null && hasMeals && hasWorkout;
    double mealPercent = 0;
    double mealCalories = 0;
    double mealGoal = _calorieGoal ?? 1800;
    double mealLeft = 0;
    double workoutPercent = 0;
    double workoutDuration = 0;
    double workoutCalories = 0;
    double mealScale = 1.0;
    if (planReady) {
      double planTotal = 0;
      final meals = plan['meals'] as Map;
      for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
        final meal = meals[mealType] is Map ? meals[mealType] as Map : <String, dynamic>{};
        planTotal += (meal['cal'] as num?)?.toDouble() ?? 0.0;
      }
      if (planTotal > 0 && planTotal < mealGoal) {
        mealScale = mealGoal / planTotal;
      }
      final dailyTotals = _calculateDailyTotals(plan);
      mealCalories = dailyTotals['cal'] ?? 0;
      mealPercent = mealGoal > 0 ? (mealCalories / mealGoal).clamp(0.0, 1.0) : 0.0;
      mealLeft = (mealGoal - mealCalories).clamp(0, mealGoal);
      final workoutSummary = _calculateWorkoutSummary(plan);
      workoutPercent = workoutSummary['progress'] ?? 0.0;
      workoutDuration = workoutSummary['duration'] ?? 0.0;
      workoutCalories = workoutSummary['calories'] ?? 0.0;
    }
    double waterPercent = _waterGoal > 0 ? _waterGlasses / _waterGoal : 0.0;
    double stepsPercent = _stepGoal > 0 ? _steps / _stepGoal : 0.0;
    int waterMl = _waterGlasses * 250;
    final cardRadius = BorderRadius.circular(18);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Plan',
            onPressed: _planLoading ? null : _refreshPlan,
          ),
        ],
      ),
      body: _planError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load plan. Please try refreshing.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshPlan,
                    child: const Text('Refresh Plan'),
                  ),
                ],
              ),
            )
          : !_planLoading && (!hasMeals || !hasWorkout)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No plan generated yet.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshPlan,
                        child: const Text('Generate Plan'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Overall Calorie Card
                      GestureDetector(
                        onTap: planReady ? _goToMealDetail : null,
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 6,
                          margin: const EdgeInsets.only(bottom: 18),
                          shape: RoundedRectangleBorder(borderRadius: cardRadius),
                          child: Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Calories', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                                      const SizedBox(height: 2),
                                      Text('${mealCalories.toStringAsFixed(0)} / ${mealGoal.toStringAsFixed(0)} kcal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                                      Text('${mealLeft.toStringAsFixed(0)} left', style: TextStyle(color: colorScheme.secondary)),
                                      const SizedBox(height: 12),
                                      LinearProgressIndicator(
                                        value: mealPercent,
                                        minHeight: 8,
                                        backgroundColor: colorScheme.surfaceVariant,
                                        color: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                AnimatedFillIcon(icon: Icons.lunch_dining, percent: mealPercent, color: colorScheme.primary, size: 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 2. Workout Logging Card
                      GestureDetector(
                        onTap: planReady ? _goToWorkoutDetail : null,
                        child: Card(
                          color: colorScheme.surface,
                          elevation: 6,
                          margin: const EdgeInsets.only(bottom: 18),
                          shape: RoundedRectangleBorder(borderRadius: cardRadius),
                          child: Padding(
                            padding: const EdgeInsets.all(22.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Workout', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                                      const SizedBox(height: 2),
                                      Text('${workoutDuration.toStringAsFixed(0)} min • ${workoutCalories.toStringAsFixed(0)} kcal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                      Text('Tap to log workout', style: TextStyle(color: colorScheme.secondary)),
                                      const SizedBox(height: 12),
                                      LinearProgressIndicator(
                                        value: workoutPercent,
                                        minHeight: 8,
                                        backgroundColor: colorScheme.surfaceVariant,
                                        color: colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 18),
                                AnimatedFillIcon(icon: Icons.fitness_center, percent: workoutPercent, color: colorScheme.primary, size: 44),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 3. Water Intake Logging Card
                      Card(
                        color: colorScheme.surface,
                        elevation: 6,
                        margin: const EdgeInsets.only(bottom: 18),
                        shape: RoundedRectangleBorder(borderRadius: cardRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Water Intake', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                                    const SizedBox(height: 2),
                                    Text('$_waterGlasses / $_waterGoal glasses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                    Text('$waterMl ml / ${(_waterGoal * 250 / 1000).toStringAsFixed(1)} L', style: TextStyle(fontSize: 14, color: colorScheme.secondary)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: _decrementWater,
                                          color: colorScheme.primary,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: _incrementWater,
                                          color: colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                    LinearProgressIndicator(
                                      value: waterPercent,
                                      minHeight: 8,
                                      backgroundColor: colorScheme.surfaceVariant,
                                      color: colorScheme.tertiary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              AnimatedFillIcon(icon: Icons.water_drop, percent: waterPercent, color: colorScheme.tertiary, size: 44),
                            ],
                          ),
                        ),
                      ),
                      // 4. Step Count Card
                      Card(
                        color: colorScheme.surface,
                        elevation: 6,
                        margin: const EdgeInsets.only(bottom: 18),
                        shape: RoundedRectangleBorder(borderRadius: cardRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Steps', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                                    const SizedBox(height: 2),
                                    Text('$_steps / $_stepGoal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          onPressed: () => _decrementSteps(1000),
                                          color: colorScheme.primary,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline),
                                          onPressed: () => _incrementSteps(1000),
                                          color: colorScheme.primary,
                                        ),
                                      ],
                                    ),
                                    LinearProgressIndicator(
                                      value: stepsPercent,
                                      minHeight: 8,
                                      backgroundColor: colorScheme.surfaceVariant,
                                      color: colorScheme.secondary,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              AnimatedFillIcon(icon: Icons.directions_walk, percent: stepsPercent, color: colorScheme.secondary, size: 44),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _incrementWater() {
    if (_waterGlasses < _waterGoal) {
      setState(() {
        _waterGlasses++;
      });
    }
  }

  void _decrementWater() {
    if (_waterGlasses > 0) {
      setState(() {
        _waterGlasses--;
      });
    }
  }

  void _goToMealDetail() async {
    if (_plan == null || _planLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    final plan = _plan;
    double mealGoal = _calorieGoal ?? 1800;
    double mealScale = 1.0;
    if (plan != null) {
      double planTotal = 0;
      final mealsRaw = plan['meals'];
      logPlanPage('[PlanPage] plan["meals"] type: \\${mealsRaw.runtimeType}, value: \\${mealsRaw}');
      final meals = mealsRaw is Map ? mealsRaw as Map : <String, dynamic>{};
      for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
        final mealRaw = meals[mealType];
        logPlanPage('[PlanPage] meals[\\"$mealType\\"] type: \\${mealRaw.runtimeType}, value: \\${mealRaw}');
        final meal = mealRaw is Map ? mealRaw as Map : <String, dynamic>{};
        planTotal += (meal['cal'] as num?)?.toDouble() ?? 0.0;
      }
      if (planTotal > 0 && planTotal < mealGoal) {
        mealScale = mealGoal / planTotal;
      }
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealDetailPage(
          plan: _plan!,
          checkboxState: Map<String, bool>.from(_checkboxState),
          mealItemQuantities: Map<String, Map<int, double>>.from(_mealItemQuantities),
          calorieGoal: _calorieGoal,
          mealScale: mealScale,
        ),
      ),
    );
    if (result is Map) {
      setState(() {
        _checkboxState = Map<String, bool>.from(result['checkboxState'] ?? _checkboxState);
        _mealItemQuantities = Map<String, Map<int, double>>.from(result['mealItemQuantities'] ?? _mealItemQuantities);
      });
      _recalculateTotalCaloriesLogged(_plan!);
    }
  }

  void _goToWorkoutDetail() async {
    if (_plan == null || _planLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    final plan = _plan;
    final workoutRaw = plan?['workout'];
    logPlanPage('[PlanPage] plan["workout"] type: \\${workoutRaw.runtimeType}, value: \\${workoutRaw}');
    final workout = workoutRaw is Map ? workoutRaw as Map<String, dynamic> : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    logPlanPage('[PlanPage] workout["exercises"] type: \\${exercisesRaw.runtimeType}, value: \\${exercisesRaw}');
    final exercises = (exercisesRaw is List) ? exercisesRaw.map(parseExercise).toList() : <Map<String, dynamic>>[];
    final exerciseKeys = List.generate(exercises.length, (i) => '${plan?['day']}-workout-ex-$i');
    final exerciseChecked = <String, bool>{};
    for (var k in exerciseKeys) {
      exerciseChecked[k] = _exerciseCompleted[k] ?? false;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailPage(
          plan: plan!,
          exerciseChecked: exerciseChecked,
        ),
      ),
    );
    if (result is Map && result.containsKey('exerciseChecked')) {
      setState(() {
        _exerciseCompleted = Map<String, bool>.from(result['exerciseChecked']);
      });
      _saveCheckboxState();
    }
  }
}

// MealDetailPage implementation
class MealDetailPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, bool> checkboxState;
  final Map<String, Map<int, double>> mealItemQuantities;
  final double? calorieGoal;
  final double? mealScale;
  const MealDetailPage({Key? key, required this.plan, required this.checkboxState, required this.mealItemQuantities, this.calorieGoal, this.mealScale}) : super(key: key);
  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  late Map<String, bool> _checkboxState;
  late Map<String, Map<int, double>> _mealItemQuantities;
  double get _mealScale => widget.mealScale ?? 1.0;
  double get _calorieGoal => widget.calorieGoal ?? 1800;
  @override
  void initState() {
    super.initState();
    _checkboxState = Map<String, bool>.from(widget.checkboxState);
    _mealItemQuantities = Map<String, Map<int, double>>.from(widget.mealItemQuantities);
  }

  double _getCaloriesForMealItem(Map meal, double quantity) {
    if (meal['cal'] != null && meal['items'] is List && meal['items'].length > 0) {
      return ((meal['cal'] / meal['items'].length) * quantity) * _mealScale;
    }
    return 0;
  }
  Map<String, double> _getMacrosForMealItem(Map meal, double quantity) {
    final macros = {'p': 0.0, 'f': 0.0, 'c': 0.0};
    if (meal['p'] != null && meal['items'] is List && meal['items'].length > 0) macros['p'] = ((meal['p'] / meal['items'].length) * quantity) * _mealScale;
    if (meal['f'] != null && meal['items'] is List && meal['items'].length > 0) macros['f'] = ((meal['f'] / meal['items'].length) * quantity) * _mealScale;
    if (meal['c'] != null && meal['items'] is List && meal['items'].length > 0) macros['c'] = ((meal['c'] / meal['items'].length) * quantity) * _mealScale;
    return macros;
  }
  Map<String, double> _calculateDailyTotals() {
    double cal = 0, p = 0, f = 0, c = 0;
    final meals = widget.plan['meals'] is Map ? widget.plan['meals'] as Map : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      final meal = meals[mealType] is Map ? meals[mealType] as Map : <String, dynamic>{};
      final items = meal['items'] is List ? meal['items'] : [];
      for (int i = 0; i < items.length; i++) {
        final key = '${widget.plan['day']}-meal-$mealType-$i';
        if (_checkboxState[key] == true) {
          final qty = _mealItemQuantities[mealType]?[i] ?? 1.0;
          cal += _getCaloriesForMealItem(meal, qty);
          final macros = _getMacrosForMealItem(meal, qty);
          p += macros['p']!;
          f += macros['f']!;
          c += macros['c']!;
        }
      }
    }
    return {'cal': cal, 'p': p, 'f': f, 'c': c};
  }

  @override
  Widget build(BuildContext context) {
    final dailyTotals = _calculateDailyTotals();
    final meals = widget.plan['meals'] is Map ? widget.plan['meals'] as Map : <String, dynamic>{};
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Details'),
        backgroundColor: colorScheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'checkboxState': _checkboxState,
                'mealItemQuantities': _mealItemQuantities,
              });
            },
            color: colorScheme.primary,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.surface,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total: ${dailyTotals['cal']!.toStringAsFixed(0)} / ${_calorieGoal.toStringAsFixed(0)} kcal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      macroSummary('P', dailyTotals['p'] ?? 0.0, 120 * _mealScale, colorScheme.tertiary),
                      macroSummary('F', dailyTotals['f'] ?? 0.0, 60 * _mealScale, colorScheme.secondary),
                      macroSummary('C', dailyTotals['c'] ?? 0.0, 220 * _mealScale, colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...['breakfast', 'lunch', 'snack', 'dinner'].map((mealType) {
            final m = meals[mealType] is Map ? meals[mealType] : <String, dynamic>{};
            final items = m['items'] is List ? m['items'].whereType<String>().toList() : [];
            return Card(
              color: colorScheme.surfaceVariant,
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mealType[0].toUpperCase() + mealType.substring(1), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ...List.generate(items.length, (i) {
                      final key = '${widget.plan['day']}-meal-$mealType-$i';
                      final checked = _checkboxState[key] ?? false;
                      final qty = _mealItemQuantities[mealType]?[i] ?? 1.0;
                      return Row(
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: (val) {
                              setState(() {
                                _checkboxState[key] = val ?? false;
                              });
                            },
                            activeColor: colorScheme.primary,
                          ),
                          Expanded(child: Text(items[i], style: checked ? TextStyle(decoration: TextDecoration.lineThrough, color: colorScheme.secondary) : TextStyle(color: colorScheme.onSurface))),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: qty.toStringAsFixed(1),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Qty', isDense: true, labelStyle: TextStyle(color: colorScheme.secondary)),
                              style: TextStyle(color: colorScheme.onSurface),
                              onChanged: (val) {
                                final v = double.tryParse(val) ?? 1.0;
                                setState(() {
                                  _mealItemQuantities[mealType] = Map<int, double>.from(_mealItemQuantities[mealType] ?? {});
                                  _mealItemQuantities[mealType]![i] = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('x1 serving', style: TextStyle(fontSize: 12, color: colorScheme.secondary)),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (m['cal'] != null) Chip(label: Text('Cal: ${((m['cal'] ?? 0) * _mealScale).toStringAsFixed(0)}'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.primary)),
                        if (m['p'] != null) Chip(label: Text('P: ${((m['p'] ?? 0) * _mealScale).toStringAsFixed(0)}g'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.tertiary)),
                        if (m['c'] != null) Chip(label: Text('C: ${((m['c'] ?? 0) * _mealScale).toStringAsFixed(0)}g'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.primary)),
                        if (m['f'] != null) Chip(label: Text('F: ${((m['f'] ?? 0) * _mealScale).toStringAsFixed(0)}g'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.secondary)),
                        if (m['iron'] != null) Chip(label: Text('Iron: ${m['iron']}mg'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.secondary)),
                        if (m['calcium'] != null) Chip(label: Text('Calcium: ${m['calcium']}mg'), backgroundColor: colorScheme.surfaceVariant, labelStyle: TextStyle(color: colorScheme.tertiary)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// WorkoutDetailPage implementation
class WorkoutDetailPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, bool> exerciseChecked;
  const WorkoutDetailPage({Key? key, required this.plan, required this.exerciseChecked}) : super(key: key);
  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  late Map<String, bool> _exerciseChecked;
  @override
  void initState() {
    super.initState();
    _exerciseChecked = Map<String, bool>.from(widget.exerciseChecked);
  }
  @override
  Widget build(BuildContext context) {
    final workout = widget.plan['workout'] is Map ? widget.plan['workout'] : {};
    final exercises = (workout['exercises'] is List) ? workout['exercises'].map(parseExercise).toList() : <Map<String, dynamic>>[];
    final exerciseKeys = List.generate(exercises.length, (i) => '${widget.plan['day']}-workout-ex-$i');
    final completed = exerciseKeys.where((k) => _exerciseChecked[k] == true).length;
    final total = exerciseKeys.length > 0 ? exerciseKeys.length : 1;
    final duration = workout['duration'] ?? 0;
    final calories = workout['calories'] ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        backgroundColor: colorScheme.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {'exerciseChecked': _exerciseChecked});
            },
            color: colorScheme.primary,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.surface,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Target: ${workout['target'] ?? '-'}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                      maxLines: 3,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Chip(
                        avatar: Icon(Icons.timer, color: colorScheme.secondary, size: 18),
                        label: Text('Duration: $duration min', style: TextStyle(color: colorScheme.secondary)),
                        backgroundColor: colorScheme.surfaceVariant,
                        shape: StadiumBorder(side: BorderSide(color: colorScheme.secondary, width: 1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                      Chip(
                        avatar: Icon(Icons.local_fire_department, color: colorScheme.tertiary, size: 18),
                        label: Text('Calories: $calories kcal', style: TextStyle(color: colorScheme.tertiary)),
                        backgroundColor: colorScheme.surfaceVariant,
                        shape: StadiumBorder(side: BorderSide(color: colorScheme.tertiary, width: 1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                      Chip(
                        avatar: Icon(Icons.check_circle, color: colorScheme.primary, size: 18),
                        label: Text('$completed / $total done', style: TextStyle(color: colorScheme.primary)),
                        backgroundColor: colorScheme.surfaceVariant,
                        shape: StadiumBorder(side: BorderSide(color: colorScheme.primary, width: 1)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Exercises:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                  const SizedBox(height: 8),
                  ...exercises.asMap().entries.map((entry) {
                    final i = entry.key;
                    final w = entry.value;
                    final key = exerciseKeys[i];
                    final checked = _exerciseChecked[key] ?? false;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: checked
                            ? colorScheme.primary.withOpacity(0.13)
                            : colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: checked ? colorScheme.primary : colorScheme.outline.withOpacity(0.13),
                          width: checked ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: checked,
                            onChanged: (val) {
                              setState(() {
                                _exerciseChecked[key] = val ?? false;
                              });
                            },
                            activeColor: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w600, color: checked ? colorScheme.primary : colorScheme.onSurface)),
                                const SizedBox(height: 2),
                                Text('${w['sets']}x${w['reps']}, Rest: ${w['rest']}s', style: TextStyle(color: colorScheme.secondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 