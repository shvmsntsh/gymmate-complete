import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:gymmate_mobile/pages/onboarding/onboarding_flow.dart';
import '../services/onboarding_service.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/editorial_mobile.dart';

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
  const AnimatedFillIcon({
    required this.icon,
    required this.percent,
    required this.color,
    this.size = 40,
    Key? key,
  }) : super(key: key);
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
  final double dVal = (val is int)
      ? val.toDouble()
      : (val is double ? val : double.tryParse(val.toString()) ?? 0.0);
  final double dGoal = (goal is int)
      ? goal.toDouble()
      : (goal is double ? goal : double.tryParse(goal.toString()) ?? 0.0);
  final percent = dGoal > 0 ? (dVal / dGoal * 100).clamp(0, 100) : 0;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label • ${percent.toStringAsFixed(0)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      Text(
        '${dVal.toStringAsFixed(0)} / ${dGoal.toStringAsFixed(0)} g',
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
}

// Place parseExercise at the top-level, outside any class, with correct Dart syntax
Map<String, dynamic> parseExercise(dynamic ex) {
  if (ex is Map<String, dynamic>) return ex;
  if (ex is String) {
    final match = RegExp(
      r'^(.*)\s*\((\d+)x(\d+)(?:,\s*rest\s*(\d+)s?)?\)?$',
    ).firstMatch(ex);
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
  final Set<String> _checkedItems = {};

  AuthProvider? _authProvider;

  // 1. Store the current day's plan only
  Map<String, dynamic>? _dayPlan;
  final bool _usedFallback = false;
  String? _aiError;

  final int _selectedDayIndex = DateTime.now().weekday - 1; // 0=Monday

  int get _todayIndex => DateTime.now().weekday - 1;

  // 1. Add loading animation and animated text sequence
  final List<String> _loadingMessages = [
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
  Map<String, Map<int, double>> _mealItemQuantities =
      {}; // key: mealType, value: {itemIdx: quantity}
  double _totalCaloriesLogged = 0;

  // Add state for daily macro goals (for demo, use static or calculate from plan if available)
  final double dailyCalGoal = 1800;
  final double dailyPGoal = 120;
  final double dailyFGoal = 60;
  final double dailyCGoal = 220;

  // Add state for workout logging
  final List<bool> _workoutCompleted = [];

  // Add state for water and steps persistence
  int _waterGlasses = 0;
  final int _waterGoal = 8; // 8 glasses per day
  int _steps = 0;
  final int _stepGoal = 8000; // Example, can be set from onboarding

  Map<String, bool> _exerciseCompleted = {}; // key: exerciseKey, value: checked

  double? _calorieGoal;

  // Progress data state (like ProgressPage)
  Map<String, dynamic>? _progressData;
  bool _progressLoading = true;
  String? _progressError;

  // Helper to get calories for a meal item (assume per serving if not specified)
  double _getCaloriesForMealItem(Map meal, double quantity) {
    // If meal['cal'] is total for all items, divide equally
    if (meal['cal'] != null &&
        meal['items'] is List &&
        meal['items'].length > 0) {
      return (meal['cal'] / meal['items'].length) * quantity;
    }
    return 0;
  }

  // Helper to get macros for a meal item (divide meal macros equally)
  Map<String, double> _getMacrosForMealItem(Map meal, double quantity) {
    final macros = {'p': 0.0, 'f': 0.0, 'c': 0.0};
    if (meal['p'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['p'] = (meal['p'] / meal['items'].length) * quantity;
    if (meal['f'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['f'] = (meal['f'] / meal['items'].length) * quantity;
    if (meal['c'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['c'] = (meal['c'] / meal['items'].length) * quantity;
    return macros;
  }

  // Calculate daily totals
  Map<String, double> _calculateDailyTotals(Map<String, dynamic> plan) {
    double cal = 0, p = 0, f = 0, c = 0;
    final mealsRaw = plan['meals'];
    logPlanPage(
      '[PlanPage] _calculateDailyTotals: plan["meals"] type: \\${mealsRaw.runtimeType}, value: \\$mealsRaw',
    );
    final meals = mealsRaw is Map ? mealsRaw : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      final mealRaw = meals[mealType];
      logPlanPage(
        '[PlanPage] _calculateDailyTotals: meals[\\"$mealType\\"] type: \\${mealRaw.runtimeType}, value: \\$mealRaw',
      );
      final meal = mealRaw is Map ? mealRaw : <String, dynamic>{};
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
    final meals = plan['meals'] is Map
        ? plan['meals'] as Map
        : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      // Defensive: ensure meal is a Map
      final meal = meals[mealType] is Map
          ? meals[mealType] as Map
          : <String, dynamic>{};
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
    logPlanPage(
      '[PlanPage] _calculateWorkoutSummary: plan["workout"] type: \\${workoutRaw.runtimeType}, value: \\$workoutRaw',
    );
    final workout = workoutRaw is Map ? workoutRaw : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    logPlanPage(
      '[PlanPage] _calculateWorkoutSummary: workout["exercises"] type: \\${exercisesRaw.runtimeType}, value: \\$exercisesRaw',
    );
    final exercises = (exercisesRaw is List)
        ? exercisesRaw.map(parseExercise).toList()
        : <Map<String, dynamic>>[];
    final exerciseKeys = List.generate(
      exercises.length,
      (i) => '${plan['day']}-workout-ex-$i',
    );
    int completed = exerciseKeys
        .where((k) => _exerciseCompleted[k] == true)
        .length;
    int total = exerciseKeys.isNotEmpty ? exerciseKeys.length : 1;
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
    _fetchProgressData();
    _loadUserDataAndBMI();
    _loadCheckboxState();
    _loadWaterAndSteps(); // <-- Load water/steps from storage
    _loadPlanIfNeeded();
    _updateCalorieGoal();
    // Animated loading message
    Future.doWhile(() async {
      if (!_planLoading) return false;
      await Future.delayed(const Duration(seconds: 2));
      if (_planLoading) {
        setState(() {
          _loadingMessageIndex =
              (_loadingMessageIndex + 1) % _loadingMessages.length;
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
        final weight =
            (userData['profile']?['weight'] as num?)?.toDouble() ?? 0.0;
        final height =
            (userData['profile']?['height'] as num?)?.toDouble() ?? 0.0;
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
    await prefs.setString(
      'plan_exercise_completed',
      json.encode(_exerciseCompleted),
    );
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
    _loadPlanFromBackend();
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

  Future<void> _loadPlanFromBackend({bool force = false}) async {
    setState(() {
      _planLoading = true;
      _planError = false;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final userData = authProvider.userData;
      if (token == null || userData == null) {
        if (mounted)
          setState(() {
            _planError = true;
            _planLoading = false;
          });
        return;
      }
      // Calculate BMI category
      final profile = userData['profile'] ?? {};
      final weight = (profile['weight'] as num?)?.toDouble() ?? 0.0;
      final height = (profile['height'] as num?)?.toDouble() ?? 0.0;
      double bmi = 0;
      String bmiCategory = 'normal';
      if (weight > 0 && height > 0) {
        bmi = weight / ((height / 100) * (height / 100));
        if (bmi < 18.5) {
          bmiCategory = 'underweight';
        } else if (bmi < 25)
          bmiCategory = 'normal';
        else if (bmi < 30)
          bmiCategory = 'overweight';
        else
          bmiCategory = 'obese';
      }
      // Prepare query params
      final goal = (userData['fitnessGoals'] as List?)?.isNotEmpty == true
          ? userData['fitnessGoals'][0]
          : 'general_fitness';
      final dietType = userData['dietPreferences']?['type'] ?? 'flexible';
      final workoutSplit = userData['workoutHabits']?['split'] ?? 'Full Body';
      final day = DateFormat('EEEE').format(DateTime.now());
      // Fetch meal plan
      final mealRes = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/plans/meal?goal=$goal&dietType=$dietType&bmiCategory=$bmiCategory&day=$day',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      // Fetch workout plan
      final workoutRes = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/plans/workout?goal=$goal&workoutSplit=$workoutSplit&bmiCategory=$bmiCategory&day=$day',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mealRes.statusCode == 200 && workoutRes.statusCode == 200) {
        final mealPlan = json.decode(mealRes.body);
        final workoutPlan = json.decode(workoutRes.body);
        setState(() {
          _plan = {
            'meals': mealPlan['meals'],
            'workout': workoutPlan,
            'day': day,
          };
          _planLoading = false;
          _planError = false;
        });
      } else {
        setState(() {
          _planError = true;
          _planLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
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
    _saveWaterAndSteps();
  }

  void _decrementSteps([int by = 1000]) {
    setState(() {
      _steps = math.max(_steps - by, 0);
    });
    _saveWaterAndSteps();
  }

  // Helper for animated progress icon
  Widget animatedIcon({
    required IconData icon,
    required double percent,
    required Color color,
    double size = 32,
  }) {
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
    final activity =
        userData['workoutHabits']?['currentActivityLevel'] ?? 'sedentary';
    final goals = userData['fitnessGoals'] ?? [];
    // Mifflin-St Jeor BMR
    double bmr = gender == 'female'
        ? 10 * weight + 6.25 * height - 5 * age - 161
        : 10 * weight + 6.25 * height - 5 * age + 5;
    // Activity multiplier
    double activityMult = 1.2;
    if (activity == 'lightly_active') {
      activityMult = 1.375;
    } else if (activity == 'moderately_active')
      activityMult = 1.55;
    else if (activity == 'very_active')
      activityMult = 1.725;
    else if (activity == 'extra_active')
      activityMult = 1.9;
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
    await _loadPlanFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Defensive: check plan structure
    final hasMeals = plan != null && plan['meals'] is Map;
    final hasWorkout = plan != null && plan['workout'] is Map;
    final planReady =
        !_planLoading && !_planError && plan != null && hasMeals && hasWorkout;
    double mealPercent = 0;
    double mealCalories = 0;
    double mealGoal = _calorieGoal ?? 1800;
    double mealLeft = 0;
    double workoutPercent = 0;
    if (planReady) {
      final dailyTotals = _calculateDailyTotals(plan);
      mealCalories = dailyTotals['cal'] ?? 0;
      mealPercent = mealGoal > 0
          ? (mealCalories / mealGoal).clamp(0.0, 1.0)
          : 0.0;
      mealLeft = (mealGoal - mealCalories).clamp(0, mealGoal);
      final workoutSummary = _calculateWorkoutSummary(plan);
      workoutPercent = workoutSummary['progress'] ?? 0.0;
    }
    double waterPercent = _waterGoal > 0 ? _waterGlasses / _waterGoal : 0.0;
    double stepsPercent = _stepGoal > 0 ? _steps / _stepGoal : 0.0;
    int waterMl = _waterGlasses * 250;
    final meals = hasMeals
        ? Map<String, dynamic>.from(plan['meals'] as Map)
        : <String, dynamic>{};
    final workout = hasWorkout
        ? Map<String, dynamic>.from(plan['workout'] as Map)
        : <String, dynamic>{};
    final workoutItems = _workoutPreviewItems(workout);
    final goalTitle = (plan?['goal'] ?? _progressData?['fitnessGoals'] ?? [])
        .toString();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: EditorialBackdrop(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialSectionHeading(
                eyebrow: 'Training Plan',
                title:
                    'Fuel your next session with a plan that matches your rhythm.',
                subtitle:
                    'Meals, workouts, hydration, and daily movement stay together so you always know what to tackle next.',
                trailing: IconButton(
                  onPressed: _planLoading ? null : _refreshPlan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 18),
              if (_planError)
                _buildEditorialState(
                  title: 'Your plan needs a fresh pull.',
                  message:
                      'We hit a snag while loading your meals and workouts. Try one more refresh and we will bring everything back into place.',
                  buttonLabel: 'Refresh Plan',
                  onPressed: _refreshPlan,
                )
              else if (_planLoading)
                _buildEditorialLoadingState()
              else if (!hasMeals || !hasWorkout)
                _buildEditorialState(
                  title: 'Your plan is still getting set up.',
                  message:
                      'Finish your profile details and we will shape a clear training and meal rhythm around your goals.',
                  buttonLabel: 'Generate Plan',
                  onPressed: _refreshPlan,
                )
              else ...[
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialKicker('Today at a Glance'),
                      const SizedBox(height: 18),
                      Center(
                        child: EditorialProgressRing(
                          progress: mealPercent,
                          value: mealCalories.toStringAsFixed(0),
                          label: 'Calories',
                          sublabel: '${mealLeft.toStringAsFixed(0)} kcal left',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: EditorialMetricTile(
                              label: 'Workout',
                              value: '${(workoutPercent * 100).round()}%',
                              icon: Icons.fitness_center_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EditorialMetricTile(
                              label: 'Water',
                              value: '$_waterGlasses/$_waterGoal',
                              icon: Icons.water_drop_rounded,
                              iconColor: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: EditorialMetricTile(
                              label: 'Steps',
                              value: _steps.toString(),
                              icon: Icons.directions_walk_rounded,
                              iconColor: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: EditorialMetricTile(
                              label: 'Focus',
                              value: _headlineFromGoal(goalTitle),
                              icon: Icons.flag_rounded,
                            ),
                          ),
                        ],
                      ),
                      if ((plan['usedFallback'] == true ||
                          plan['fallback'] == true)) ...[
                        const SizedBox(height: 16),
                        _fallbackBanner(colorScheme),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildProgressCard(),
                const SizedBox(height: 18),
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialSectionHeading(
                        eyebrow: 'Coming Up Next',
                        title: 'Your next workout is ready when you are.',
                      ),
                      const SizedBox(height: 18),
                      EditorialBlurImage(
                        height: 220,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.surfaceContainerHighest,
                                    colorScheme.surface,
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              right: 16,
                              bottom: 0,
                              child: Image.asset(
                                'assets/images/member_illustration.png',
                                height: 170,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 120,
                              top: 18,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface.withValues(
                                        alpha: 0.9,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'NEXT SESSION',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _workoutHeadline(workout, workoutItems),
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _workoutSummaryText(workout, workoutItems),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildInfoChip(
                            icon: Icons.timer_outlined,
                            label: '${workout['duration'] ?? 0} min',
                          ),
                          _buildInfoChip(
                            icon: Icons.local_fire_department_outlined,
                            label: '${workout['calories'] ?? 0} kcal',
                          ),
                          _buildInfoChip(
                            icon: Icons.playlist_add_check_circle_outlined,
                            label: '${workoutItems.length} moves',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: EditorialPrimaryButton(
                          label: 'Open Workout',
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF390C00),
                          ),
                          onPressed: _goToWorkoutDetail,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialSectionHeading(
                        eyebrow: 'Meals Today',
                        title: 'A steady food rhythm for the day ahead.',
                      ),
                      const SizedBox(height: 18),
                      ...['breakfast', 'lunch', 'snack', 'dinner'].map(
                        (mealType) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildMealPreviewCard(
                            mealType,
                            meals[mealType],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: EditorialPrimaryButton(
                          label: 'Open Full Meal Plan',
                          trailing: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF390C00),
                          ),
                          onPressed: _goToMealDetail,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTrackableCard(
                        title: 'Hydration',
                        value: '$_waterGlasses / $_waterGoal',
                        subtitle: '$waterMl ml today',
                        icon: Icons.water_drop_rounded,
                        progress: waterPercent,
                        onMinus: _decrementWater,
                        onPlus: _incrementWater,
                        progressColor: colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTrackableCard(
                        title: 'Steps',
                        value: '$_steps',
                        subtitle: 'Goal $_stepGoal',
                        icon: Icons.directions_walk_rounded,
                        progress: stepsPercent,
                        onMinus: () => _decrementSteps(1000),
                        onPlus: () => _incrementSteps(1000),
                        progressColor: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialLoadingState() {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialKicker('Loading'),
          const SizedBox(height: 18),
          Text(
            _loadingMessages[_loadingMessageIndex % _loadingMessages.length],
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          Text(
            'We are pulling your meals, workout focus, and daily targets into one clear view.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildEditorialState({
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialKicker('Plan Status'),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: EditorialPrimaryButton(
              label: buttonLabel,
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF390C00),
              ),
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _workoutPreviewItems(
    Map<String, dynamic> workout,
  ) {
    final exercisesRaw = workout['exercises'];
    if (exercisesRaw is List) {
      return exercisesRaw.map(parseExercise).toList();
    }
    if (exercisesRaw is Map) {
      final previewItems = <Map<String, dynamic>>[];
      for (final entry in exercisesRaw.entries) {
        final group = entry.value;
        if (group is Map && group['items'] is List) {
          previewItems.addAll(
            List<Map<String, dynamic>>.from(group['items']).map(parseExercise),
          );
        }
      }
      return previewItems;
    }
    return <Map<String, dynamic>>[];
  }

  String _headlineFromGoal(String rawGoal) {
    if (rawGoal.toLowerCase().contains('gain')) return 'Build';
    if (rawGoal.toLowerCase().contains('lose')) return 'Lean';
    if (rawGoal.toLowerCase().contains('strength')) return 'Power';
    return 'Focus';
  }

  String _workoutHeadline(
    Map<String, dynamic> workout,
    List<Map<String, dynamic>> items,
  ) {
    final target = workout['target']?.toString();
    if (target != null && target.trim().isNotEmpty) {
      return target;
    }
    if (items.isNotEmpty) {
      return items.first['name']?.toString() ?? 'Your next gym session';
    }
    return 'Your next gym session';
  }

  String _workoutSummaryText(
    Map<String, dynamic> workout,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return 'A focused session is being lined up for you now. Open the workout to see the full structure.';
    }
    final names = items
        .take(3)
        .map((item) => item['name']?.toString() ?? 'Move')
        .join(', ');
    return '$names${items.length > 3 ? ' and more' : ''} keep today anchored in the right effort.';
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildMealPreviewCard(String mealType, dynamic mealRaw) {
    final theme = Theme.of(context);
    final meal = mealRaw is Map
        ? Map<String, dynamic>.from(mealRaw)
        : <String, dynamic>{};
    final items = meal['items'] is List
        ? List<dynamic>.from(meal['items'])
        : <dynamic>[];
    final calories = ((meal['cal'] as num?) ?? 0).toDouble();
    final preview = items.isEmpty
        ? 'Details will appear here once your meal is ready.'
        : items.take(2).join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Icon(_mealIcon(mealType), color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_abc(mealType), style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  '${calories.toStringAsFixed(0)} kcal • ${items.length} items',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(preview, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'snack':
        return Icons.cookie_outlined;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Widget _buildTrackableCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required double progress,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
    required Color progressColor,
  }) {
    final theme = Theme.of(context);

    return EditorialSurface(
      padding: const EdgeInsets.all(18),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: progressColor),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onMinus,
                  child: const Icon(Icons.remove_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onPlus,
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _incrementWater() {
    if (_waterGlasses < _waterGoal) {
      setState(() {
        _waterGlasses++;
      });
      _saveWaterAndSteps();
    }
  }

  void _decrementWater() {
    if (_waterGlasses > 0) {
      setState(() {
        _waterGlasses--;
      });
      _saveWaterAndSteps();
    }
  }

  void _goToMealDetail() async {
    if (_plan == null || _planLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    final plan = _plan;
    double mealGoal = _calorieGoal ?? 1800;
    double mealScale = 1.0;
    if (plan != null) {
      double planTotal = 0;
      final mealsRaw = plan['meals'];
      logPlanPage(
        '[PlanPage] plan["meals"] type: \\${mealsRaw.runtimeType}, value: \\$mealsRaw',
      );
      final meals = mealsRaw is Map ? mealsRaw : <String, dynamic>{};
      for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
        final mealRaw = meals[mealType];
        logPlanPage(
          '[PlanPage] meals[\\"$mealType\\"] type: \\${mealRaw.runtimeType}, value: \\$mealRaw',
        );
        final meal = mealRaw is Map ? mealRaw : <String, dynamic>{};
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
          mealItemQuantities: Map<String, Map<int, double>>.from(
            _mealItemQuantities,
          ),
          calorieGoal: _calorieGoal,
          mealScale: mealScale,
        ),
      ),
    );
    if (result is Map) {
      setState(() {
        _checkboxState = Map<String, bool>.from(
          result['checkboxState'] ?? _checkboxState,
        );
        _mealItemQuantities = Map<String, Map<int, double>>.from(
          result['mealItemQuantities'] ?? _mealItemQuantities,
        );
      });
      _recalculateTotalCaloriesLogged(_plan!);
    }
  }

  void _goToWorkoutDetail() async {
    if (_plan == null || _planLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    final plan = _plan;
    final workoutRaw = plan?['workout'];
    logPlanPage(
      '[PlanPage] plan["workout"] type: \\${workoutRaw.runtimeType}, value: \\$workoutRaw',
    );
    final workout = workoutRaw is Map
        ? workoutRaw as Map<String, dynamic>
        : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    logPlanPage(
      '[PlanPage] workout["exercises"] type: \\${exercisesRaw.runtimeType}, value: \\$exercisesRaw',
    );
    final exercises = (exercisesRaw is List)
        ? exercisesRaw.map(parseExercise).toList()
        : <Map<String, dynamic>>[];
    final exerciseKeys = List.generate(
      exercises.length,
      (i) => '${plan?['day']}-workout-ex-$i',
    );
    final exerciseChecked = <String, bool>{};
    for (var k in exerciseKeys) {
      exerciseChecked[k] = _exerciseCompleted[k] ?? false;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WorkoutDetailPage(plan: plan!, exerciseChecked: exerciseChecked),
      ),
    );
    if (result is Map && result.containsKey('exerciseChecked')) {
      setState(() {
        _exerciseCompleted = Map<String, bool>.from(result['exerciseChecked']);
      });
      _saveCheckboxState();
    }
  }

  Widget _fallbackBanner(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No exact plan found for your onboarding. Showing the closest match.',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editOnboarding() async {
    final provider = Provider.of<AuthProvider>(context, listen: false);
    final onboardingProvider = Provider.of<OnboardingProvider>(
      context,
      listen: false,
    );
    if (_progressData != null) {
      onboardingProvider.loadFromProgress(_progressData!);
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const OnboardingFlow()));
    await provider.refreshUser();
    await _fetchProgressData();
    await _loadPlanFromBackend(force: true); // <-- Always force plan refresh
    if (mounted) setState(() {});
  }

  // Helper to capitalize first letter (Abc format)
  String _abc(String? value) {
    if (value == null || value.isEmpty) return '-';
    return value[0].toUpperCase() +
        value.substring(1).toLowerCase().replaceAll('_', ' ');
  }

  Widget _buildProgressCard() {
    if (_progressLoading) {
      return const EditorialSurface(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_progressError != null) {
      return EditorialSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditorialSectionHeading(
              eyebrow: 'Profile Snapshot',
              title: 'Your stored details need another pull.',
            ),
            const SizedBox(height: 10),
            Text('Error loading profile: $_progressError'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: EditorialPrimaryButton(
                label: 'Retry',
                trailing: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF390C00),
                ),
                onPressed: _fetchProgressData,
              ),
            ),
          ],
        ),
      );
    }
    final data = _progressData;
    if (data == null) return const SizedBox.shrink();
    final profile = (data['profile'] is Map)
        ? Map<String, dynamic>.from(data['profile'])
        : <String, dynamic>{};
    final fitnessGoals = data['fitnessGoals'] is List
        ? List<String>.from(data['fitnessGoals'])
        : <String>[];
    final dietPreferences = (data['dietPreferences'] is Map)
        ? Map<String, dynamic>.from(data['dietPreferences'])
        : <String, dynamic>{};
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final textStyle = theme.textTheme.bodyMedium;
    final boldStyle = textStyle?.copyWith(fontWeight: FontWeight.bold);
    return EditorialSurface(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialSectionHeading(
              eyebrow: 'Profile Snapshot',
              title: 'The details shaping your current plan.',
              subtitle:
                  'These settings keep your meals, movement, and pacing grounded in your real routine.',
              trailing: IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit onboarding',
                onPressed: _editOnboarding,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: EditorialMetricTile(
                    label: 'Age',
                    value: '${profile['age'] ?? '-'}',
                    icon: Icons.cake_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EditorialMetricTile(
                    label: 'Weight',
                    value: '${profile['weight'] ?? '-'} kg',
                    icon: Icons.monitor_weight_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: EditorialMetricTile(
                    label: 'Gender',
                    value: _abc(profile['gender']?.toString()),
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EditorialMetricTile(
                    label: 'Height',
                    value: '${profile['height'] ?? '-'} cm',
                    icon: Icons.height_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.flag, color: iconColor, size: 20),
                const SizedBox(width: 6),
                Text('Fitness Goals:', style: boldStyle),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fitnessGoals.isEmpty
                  ? [_buildProfileChip('Balanced training')]
                  : fitnessGoals.map(_buildProfileChip).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: iconColor, size: 20),
                const SizedBox(width: 6),
                Text('Diet Preferences:', style: boldStyle),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildProfileChip(
                  'Diet: ${_abc(dietPreferences['type']?.toString())}',
                ),
                _buildProfileChip(
                  'Meals: ${dietPreferences['dailyMeals'] ?? '-'} daily',
                ),
                _buildProfileChip(
                  'Water: ${dietPreferences['waterIntake'] ?? '-'} glasses',
                ),
                _buildProfileChip(
                  'Allergies: ${((dietPreferences['allergies'] is List && (dietPreferences['allergies'] as List).isNotEmpty) ? (dietPreferences['allergies'] as List).map((e) => _abc(e.toString())).join(', ') : 'None')}',
                ),
                _buildProfileChip(
                  'Restrictions: ${((dietPreferences['restrictions'] is List && (dietPreferences['restrictions'] as List).isNotEmpty) ? (dietPreferences['restrictions'] as List).map((e) => _abc(e.toString())).join(', ') : 'None')}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileChip(String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }

  Future<void> _fetchProgressData() async {
    setState(() {
      _progressLoading = true;
      _progressError = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) throw Exception('No authentication token available');
      final service = OnboardingService();
      service.setToken(token);
      final data = await service.getUserProgress();
      setState(() {
        _progressData = data;
        _progressLoading = false;
      });
    } catch (e) {
      setState(() {
        _progressError = e.toString();
        _progressLoading = false;
      });
    }
  }

  // Persist water and steps to SharedPreferences
  Future<void> _saveWaterAndSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('plan_water_glasses', _waterGlasses);
    await prefs.setInt('plan_steps', _steps);
  }

  Future<void> _loadWaterAndSteps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGlasses = prefs.getInt('plan_water_glasses') ?? 0;
      _steps = prefs.getInt('plan_steps') ?? 0;
    });
  }
}

// MealDetailPage implementation
class MealDetailPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, bool> checkboxState;
  final Map<String, Map<int, double>> mealItemQuantities;
  final double? calorieGoal;
  final double? mealScale;
  const MealDetailPage({
    Key? key,
    required this.plan,
    required this.checkboxState,
    required this.mealItemQuantities,
    this.calorieGoal,
    this.mealScale,
  }) : super(key: key);
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
    _mealItemQuantities = Map<String, Map<int, double>>.from(
      widget.mealItemQuantities,
    );
  }

  double _getCaloriesForMealItem(Map meal, double quantity) {
    if (meal['cal'] != null &&
        meal['items'] is List &&
        meal['items'].length > 0) {
      return ((meal['cal'] / meal['items'].length) * quantity) * _mealScale;
    }
    return 0;
  }

  Map<String, double> _getMacrosForMealItem(Map meal, double quantity) {
    final macros = {'p': 0.0, 'f': 0.0, 'c': 0.0};
    if (meal['p'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['p'] =
          ((meal['p'] / meal['items'].length) * quantity) * _mealScale;
    if (meal['f'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['f'] =
          ((meal['f'] / meal['items'].length) * quantity) * _mealScale;
    if (meal['c'] != null && meal['items'] is List && meal['items'].length > 0)
      macros['c'] =
          ((meal['c'] / meal['items'].length) * quantity) * _mealScale;
    return macros;
  }

  Map<String, double> _calculateDailyTotals() {
    double cal = 0, p = 0, f = 0, c = 0;
    final meals = widget.plan['meals'] is Map
        ? widget.plan['meals'] as Map
        : <String, dynamic>{};
    for (final mealType in ['breakfast', 'lunch', 'snack', 'dinner']) {
      final meal = meals[mealType] is Map
          ? meals[mealType] as Map
          : <String, dynamic>{};
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
    final meals = widget.plan['meals'] is Map
        ? widget.plan['meals'] as Map
        : <String, dynamic>{};
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Details'),
        backgroundColor: colorScheme.surface,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.2,
              ),
            ),
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total: ${dailyTotals['cal']!.toStringAsFixed(0)} / ${_calorieGoal.toStringAsFixed(0)} kcal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      macroSummary(
                        'P',
                        dailyTotals['p'] ?? 0.0,
                        120 * _mealScale,
                        Theme.of(context).colorScheme.tertiary,
                      ),
                      macroSummary(
                        'F',
                        dailyTotals['f'] ?? 0.0,
                        60 * _mealScale,
                        Theme.of(context).colorScheme.secondary,
                      ),
                      macroSummary(
                        'C',
                        dailyTotals['c'] ?? 0.0,
                        220 * _mealScale,
                        Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...['breakfast', 'lunch', 'snack', 'dinner'].map((mealType) {
            final m = meals[mealType] is Map
                ? meals[mealType]
                : <String, dynamic>{};
            final items = m['items'] is List
                ? List<Map<String, dynamic>>.from(m['items'])
                : <Map<String, dynamic>>[];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.2,
                ),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealType[0].toUpperCase() + mealType.substring(1),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    ...List.generate(items.length, (i) {
                      final item = items[i];
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
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? '',
                                  style: checked
                                      ? TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        )
                                      : TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                ),
                                Text(
                                  item['quantity'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ),
                                Text(
                                  'P: ${item['macros']?['protein'] ?? 0}g  C: ${item['macros']?['carbs'] ?? 0}g  F: ${item['macros']?['fats'] ?? 0}g',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: qty.toStringAsFixed(1),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Qty',
                                isDense: true,
                                labelStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: (val) {
                                final v = double.tryParse(val) ?? 1.0;
                                setState(() {
                                  _mealItemQuantities[mealType] =
                                      Map<int, double>.from(
                                        _mealItemQuantities[mealType] ?? {},
                                      );
                                  _mealItemQuantities[mealType]![i] = v;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'x1 serving',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (m['cal'] != null)
                          Chip(
                            label: Text(
                              'Cal: ${((m['cal'] ?? 0) * _mealScale).toStringAsFixed(0)}',
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (m['p'] != null)
                          Chip(
                            label: Text(
                              'P: ${((m['p'] ?? 0) * _mealScale).toStringAsFixed(0)}g',
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                        if (m['c'] != null)
                          Chip(
                            label: Text(
                              'C: ${((m['c'] ?? 0) * _mealScale).toStringAsFixed(0)}g',
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (m['f'] != null)
                          Chip(
                            label: Text(
                              'F: ${((m['f'] ?? 0) * _mealScale).toStringAsFixed(0)}g',
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        if (m['iron'] != null)
                          Chip(
                            label: Text('Iron: ${m['iron']}mg'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        if (m['calcium'] != null)
                          Chip(
                            label: Text('Calcium: ${m['calcium']}mg'),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
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
  const WorkoutDetailPage({
    Key? key,
    required this.plan,
    required this.exerciseChecked,
  }) : super(key: key);
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
    final exercisesMap = (workout['exercises'] is Map)
        ? Map<String, dynamic>.from(workout['exercises'])
        : <String, dynamic>{};
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Details'),
        backgroundColor: colorScheme.surface,
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.2,
              ),
            ),
            color: Theme.of(context).colorScheme.surface,
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
                        color: Theme.of(context).colorScheme.primary,
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
                        avatar: Icon(
                          Icons.timer,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 18,
                        ),
                        label: Text(
                          'Duration: ${workout['duration'] ?? 0} min',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.local_fire_department,
                          color: Theme.of(context).colorScheme.tertiary,
                          size: 18,
                        ),
                        label: Text(
                          'Calories: ${workout['calories'] ?? 0} kcal',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.tertiary,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                      Chip(
                        avatar: Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        label: Text(
                          '${_exerciseChecked.values.where((v) => v).length} / ${_exerciseChecked.isNotEmpty ? _exerciseChecked.length : 1} done',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Exercises:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...exercisesMap.entries.expand((entry) {
                    final group = entry.value;
                    final groupName = group['muscleGroup'] ?? entry.key;
                    final items = group['items'] is List
                        ? List<Map<String, dynamic>>.from(group['items'])
                        : <Map<String, dynamic>>[];
                    return [
                      Text(
                        groupName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      ...List.generate(items.length, (i) {
                        final ex = items[i];
                        final key =
                            '${widget.plan['day']}-workout-${entry.key}-$i';
                        final checked = _exerciseChecked[key] ?? false;
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: checked
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.13)
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: checked
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.13),
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
                                activeColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex['name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: checked
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${ex['sets']}x${ex['reps']}, ${ex['muscleGroup']}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ];
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
