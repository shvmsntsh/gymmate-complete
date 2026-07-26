import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../services/onboarding_service.dart';
import '../services/member_hub_service.dart';
import '../utils/date_format.dart';
import '../widgets/async_states.dart';
import '../widgets/editorial_mobile.dart';
import 'package:gymmate_mobile/pages/member_onboarding_page.dart';
import 'package:gymmate_mobile/services/member_plan_service.dart';

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
            Icon(icon, color: color.withValues(alpha: 0.12), size: size),
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

Map<String, dynamic> _planMealItemAsMap(dynamic item) {
  if (item is Map) return Map<String, dynamic>.from(item);
  return <String, dynamic>{};
}

String _planFriendlyLabel(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  final cleaned = value.replaceAll('_', ' ').trim();
  return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
}

String _planMealPrimaryTitle(Map<String, dynamic> item) {
  final name = item['name']?.toString().trim();
  if (name != null && name.isNotEmpty) return name;
  return 'Meal details ready';
}

String _planMealServingLine(Map<String, dynamic> item) {
  final quantity = item['quantity']?.toString().trim();
  if (quantity != null && quantity.isNotEmpty) return quantity;
  return '';
}

String _planMealTimeLabel(Map<String, dynamic> item, String fallbackMealType) {
  final raw = item['time']?.toString().trim();
  if (raw != null && raw.isNotEmpty) return raw;
  return _planFriendlyLabel(fallbackMealType);
}

String _planMealMacroSummary(Map<String, dynamic> item) {
  final macros = item['macros'];
  if (macros is! Map) return '';
  String formatMacro(dynamic raw) {
    final value = (raw as num?)?.toDouble() ?? 0.0;
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  final protein = macros['protein'] ?? macros['p'];
  final carbs = macros['carbs'] ?? macros['c'];
  final fats = macros['fats'] ?? macros['f'];
  final parts = <String>[];
  if (protein != null) parts.add('P ${formatMacro(protein)}g');
  if (carbs != null) parts.add('C ${formatMacro(carbs)}g');
  if (fats != null) parts.add('F ${formatMacro(fats)}g');
  return parts.join(' • ');
}

IconData _planMealIcon(String mealType) {
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

List<String> _orderedMealKeysFromRaw(Map<String, dynamic> meals) {
  const preferredOrder = <String>[
    'breakfast',
    'mid_morning',
    'mid-morning',
    'lunch',
    'snack',
    'pre_workout',
    'pre-workout',
    'post_workout',
    'post-workout',
    'dinner',
  ];

  final keys = meals.keys.map((key) => key.toString()).toList();
  final ordered = <String>[];

  for (final key in preferredOrder) {
    if (keys.contains(key)) ordered.add(key);
  }
  for (final key in keys) {
    if (!ordered.contains(key)) ordered.add(key);
  }

  return ordered;
}

class PlanPage extends StatefulWidget {
  const PlanPage({Key? key}) : super(key: key);

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> with WidgetsBindingObserver {
  AuthProvider? _authProvider;

  // Rotating loading-message animation shown while the personalised plan
  // (profile + workout + meal plan) is being fetched.
  final List<String> _loadingMessages = [
    '🧠 Generating your personalized fitness plan…',
    '🏋️‍♂️ Matching workouts to your goals…',
    '🥗 Balancing meals just for you…',
  ];
  int _loadingMessageIndex = 0;

  Map<String, bool> _checkboxState = {};

  // Add state for meal logging
  Map<String, Map<int, double>> _mealItemQuantities =
      {}; // key: mealType, value: {itemIdx: quantity}

  // Add state for water and steps persistence
  int _waterGlasses = 0;
  final int _waterGoal = 8; // 8 glasses per day
  int _steps = 0;
  final int _stepGoal = 8000; // Example, can be set from onboarding

  Map<String, bool> _exerciseCompleted = {}; // key: exerciseKey, value: checked

  // Completion state (DailyPlanLog) is fetched fresh for every calendar day -
  // these track whether that fetch has completed/failed for the date the
  // page currently has loaded, so checkbox state is never rendered from
  // stale local state before the server has had a chance to answer.
  bool _planLogLoaded = false;
  bool _planLogLoading = true;
  String? _planLogError;
  String? _loadedForDate;

  // Personalised plan state (dynamic, from /api/member/me/*) - this is the
  // single source of truth for what's displayed on this page. The old
  // /api/plans/meal|workout pipeline and its cached_plan_* SharedPreferences
  // cache have been retired in favour of this.
  Map<String, dynamic>? _memberProfile;
  Map<String, dynamic>? _memberWorkoutPlan;
  Map<String, dynamic>? _memberMealPlan;
  bool _memberPlanLoading = true;
  String? _memberPlanError;

  // Progress data state (like ProgressPage)
  Map<String, dynamic>? _progressData;
  bool _progressLoading = true;
  String? _progressError;
  Map<String, dynamic>? _membershipSummary;
  bool _membershipLoading = true;
  String? _membershipError;

  double _itemCalories(Map<String, dynamic> item) {
    final directCal =
        (item['calories'] as num?)?.toDouble() ??
        (item['cal'] as num?)?.toDouble();
    if (directCal != null && directCal > 0) return directCal;

    final macros = item['macros'];
    if (macros is Map) {
      final protein =
          (macros['protein'] as num?)?.toDouble() ??
          (macros['p'] as num?)?.toDouble() ??
          0.0;
      final carbs =
          (macros['carbs'] as num?)?.toDouble() ??
          (macros['c'] as num?)?.toDouble() ??
          0.0;
      final fats =
          (macros['fats'] as num?)?.toDouble() ??
          (macros['f'] as num?)?.toDouble() ??
          0.0;
      return (protein * 4) + (carbs * 4) + (fats * 9);
    }

    return 0;
  }

  double _mealPlannedCalories(Map meal) {
    if (meal['cal'] is num) return (meal['cal'] as num).toDouble();
    final items = meal['items'] is List
        ? List<dynamic>.from(meal['items'])
        : [];
    return items
        .map((item) => _itemCalories(_mealItemAsMap(item)))
        .fold<double>(0, (sum, value) => sum + value);
  }

  double _asDouble(dynamic raw) => (raw as num?)?.toDouble() ?? 0.0;

  // Daily calorie/macro targets now come straight from the server-computed
  // MemberMealPlan (dailyCalories/macros, TDEE-aware) via _todayPlan -
  // there's no need to re-derive them locally from onboarding data the way
  // the old pipeline used to.
  Map<String, double> _dailyTargetsForPlan(Map<String, dynamic> plan) {
    final raw = plan['dailyTargets'];
    if (raw is Map) {
      return {
        'calories': _asDouble(raw['calories']),
        'protein': _asDouble(raw['protein']),
        'carbs': _asDouble(raw['carbs']),
        'fat': _asDouble(raw['fat']),
      };
    }
    return {'calories': 1800, 'protein': 120, 'carbs': 220, 'fat': 60};
  }

  // Helper to get calories for a meal item
  double _getCaloriesForMealItem(Map meal, double quantity, dynamic item) {
    final itemMap = _mealItemAsMap(item);
    return _itemCalories(itemMap) * quantity;
  }

  // Helper to get macros for a meal item
  Map<String, double> _getMacrosForMealItem(
    Map meal,
    double quantity,
    dynamic item,
  ) {
    final itemMap = _mealItemAsMap(item);
    final rawMacros = itemMap['macros'];
    if (rawMacros is Map) {
      final protein =
          (rawMacros['protein'] as num?)?.toDouble() ??
          (rawMacros['p'] as num?)?.toDouble() ??
          0.0;
      final carbs =
          (rawMacros['carbs'] as num?)?.toDouble() ??
          (rawMacros['c'] as num?)?.toDouble() ??
          0.0;
      final fats =
          (rawMacros['fats'] as num?)?.toDouble() ??
          (rawMacros['f'] as num?)?.toDouble() ??
          0.0;
      return {
        'p': protein * quantity,
        'c': carbs * quantity,
        'f': fats * quantity,
      };
    }
    return {'p': 0.0, 'f': 0.0, 'c': 0.0};
  }

  // Calculate daily totals
  Map<String, double> _calculateDailyTotals(Map<String, dynamic> plan) {
    double cal = 0, p = 0, f = 0, c = 0;
    final mealsRaw = plan['meals'];
    logPlanPage(
      '[PlanPage] _calculateDailyTotals: plan["meals"] type: \\${mealsRaw.runtimeType}, value: \\$mealsRaw',
    );
    final meals = mealsRaw is Map ? mealsRaw : <String, dynamic>{};
    final mealKeys = _orderedMealKeysFromRaw(Map<String, dynamic>.from(meals));
    for (final mealType in mealKeys) {
      final mealRaw = meals[mealType];
      logPlanPage(
        '[PlanPage] _calculateDailyTotals: meals[\\"$mealType\\"] type: \\${mealRaw.runtimeType}, value: \\$mealRaw',
      );
      final meal = mealRaw is Map ? mealRaw : <String, dynamic>{};
      final items = meal['items'] is List ? meal['items'] : [];
      for (int i = 0; i < items.length; i++) {
        final key = 'meal-$mealType-$i';
        if (_checkboxState[key] == true) {
          final qty = _mealItemQuantities[mealType]?[i] ?? 1.0;
          cal += _getCaloriesForMealItem(meal, qty, items[i]);
          final macros = _getMacrosForMealItem(meal, qty, items[i]);
          p += macros['p']!;
          f += macros['f']!;
          c += macros['c']!;
        }
      }
    }
    return {'cal': cal, 'p': p, 'f': f, 'c': c};
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
    final workout = workoutRaw is Map
        ? Map<String, dynamic>.from(workoutRaw)
        : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    logPlanPage(
      '[PlanPage] _calculateWorkoutSummary: workout["exercises"] type: \\${exercisesRaw.runtimeType}, value: \\$exercisesRaw',
    );
    final exercises = _workoutPreviewItems(workout);
    final exerciseKeys = List.generate(
      exercises.length,
      (i) => 'workout-ex-$i',
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
    WidgetsBinding.instance.addObserver(this);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _authProvider?.addListener(_onAuthChanged);
    _fetchProgressData();
    _loadWaterAndSteps(); // <-- Load water/steps from storage
    _loadMembershipHub();
    _loadPersonalisedPlan();
    // Animated loading message
    Future.doWhile(() async {
      if (!_memberPlanLoading) return false;
      await Future.delayed(const Duration(seconds: 2));
      if (_memberPlanLoading) {
        setState(() {
          _loadingMessageIndex =
              (_loadingMessageIndex + 1) % _loadingMessages.length;
        });
      }
      return _memberPlanLoading;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfDayChanged();
    }
  }

  // A session left open across midnight (or across a day boundary while the
  // app was backgrounded) should not keep showing yesterday's plan/checkbox
  // state. Compared against on every resume, and cheaply re-checked on every
  // build() too since IndexedStack keeps this page's State alive across tab
  // switches (no route-level pop/push to hook into).
  void _refreshIfDayChanged() {
    if (_loadedForDate == null) return;
    if (_loadedForDate != _currentPlanDateKey()) {
      _checkboxState = {};
      _exerciseCompleted = {};
      _mealItemQuantities = {};
      _planLogLoaded = false;
      _loadPersonalisedPlan();
    }
  }

  void _onAuthChanged() {
    if (_authProvider != null && !_authProvider!.isAuth) {
      setState(() {
        _checkboxState = {};
        _exerciseCompleted = {};
        _mealItemQuantities = {};
        _memberProfile = null;
        _memberWorkoutPlan = null;
        _memberMealPlan = null;
        _memberPlanLoading = false;
        _memberPlanError = null;
        _planLogLoaded = false;
        _planLogLoading = false;
        _planLogError = null;
        _loadedForDate = null;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authProvider?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _loadMembershipHub() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    try {
      final payload = await MemberHubService.fetchMembershipSummary(token);
      if (!mounted) return;
      setState(() {
        _membershipSummary = Map<String, dynamic>.from(
          payload['membership'] ?? const {},
        );
        _membershipLoading = false;
        _membershipError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _membershipLoading = false;
        _membershipError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadPersonalisedPlan() async {
    setState(() {
      _memberPlanLoading = true;
      _memberPlanError = null;
    });
    final token = _authProvider?.token;
    if (token == null) {
      setState(() => _memberPlanLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        MemberPlanService.getProfile(token),
        MemberPlanService.getWorkoutPlan(token),
        MemberPlanService.getMealPlan(token),
      ]);
      if (!mounted) return;
      setState(() {
        _memberProfile = results[0];
        _memberWorkoutPlan = results[1];
        _memberMealPlan = results[2];
        _memberPlanLoading = false;
      });
      await _hydratePlanLogForCurrentPlan();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      final is404 = msg.contains('404') ||
          msg.toLowerCase().contains('no workout plan') ||
          msg.toLowerCase().contains('no meal plan') ||
          msg.toLowerCase().contains('not assigned') ||
          msg.toLowerCase().contains('not found');
      setState(() {
        _memberPlanLoading = false;
        _memberPlanError = is404 ? '__onboarding_needed__' : msg;
      });
    }
  }

  // Completion state lives entirely on the server (DailyPlanLog, keyed by
  // real {memberId, date}) now - there's no local persistence step here
  // beyond the in-memory _checkboxState/_exerciseCompleted/
  // _mealItemQuantities maps, which _hydratePlanLogForCurrentPlan populates
  // from the server on load and _syncPlanLogToServer pushes back on every
  // toggle. The old global, unscoped SharedPreferences cache
  // (plan_checkbox_state / plan_exercise_completed /
  // plan_meal_item_quantities) has been removed - it could serve a
  // yesterday's-checkmarks-look-done-today bug if the server sync ever
  // silently failed.
  Future<void> _persistCompletionChange() async {
    setState(() {}); // re-render immediately with the optimistic local state
    await _syncPlanLogToServer();
  }

  String _currentPlanDateKey() =>
      DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, dynamic> _buildPlanLogPayload() {
    final plan = _todayPlan;
    final loggedMealItems = <String, double>{};
    final loggedWorkoutItems = <String, bool>{};

    _checkboxState.forEach((key, value) {
      if (value != true || !key.startsWith('meal-')) return;
      final parts = key.split('-');
      final mealType = parts.length >= 2 ? parts[1] : '';
      final index = parts.isNotEmpty ? int.tryParse(parts.last) ?? 0 : 0;
      loggedMealItems[key] = _mealItemQuantities[mealType]?[index] ?? 1.0;
    });

    _exerciseCompleted.forEach((key, value) {
      if (value == true && key.startsWith('workout-')) {
        loggedWorkoutItems[key] = true;
      }
    });

    final dailyTotals = plan == null
        ? {'cal': 0.0, 'p': 0.0, 'c': 0.0, 'f': 0.0}
        : _calculateDailyTotals(plan);
    final workoutSummary = plan == null
        ? {'progress': 0.0}
        : _calculateWorkoutSummary(plan);
    final mealGoal = plan == null
        ? 1800.0
        : (_dailyTargetsForPlan(plan)['calories'] ?? 1800.0);
    final calorieProgress = mealGoal > 0
        ? ((dailyTotals['cal'] ?? 0) / mealGoal).clamp(0.0, 1.0)
        : 0.0;
    final workoutProgress = ((workoutSummary['progress'] ?? 0.0) as num)
        .toDouble()
        .clamp(0.0, 1.0);

    return {
      'date': _currentPlanDateKey(),
      'loggedMealItems': loggedMealItems,
      'loggedWorkoutItems': loggedWorkoutItems,
      'water': _waterGlasses,
      'steps': _steps,
      'caloriesLogged': dailyTotals['cal'] ?? 0,
      'proteinLogged': dailyTotals['p'] ?? 0,
      'carbsLogged': dailyTotals['c'] ?? 0,
      'fatLogged': dailyTotals['f'] ?? 0,
      'completionScore': ((calorieProgress + workoutProgress) / 2).clamp(
        0.0,
        1.0,
      ),
    };
  }

  Future<void> _hydratePlanLogForCurrentPlan() async {
    if (_todayPlan == null || _memberPlanLoading || _planLogLoaded) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    final dateKey = _currentPlanDateKey();

    setState(() {
      _planLogLoading = true;
      _planLogError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/member/plan-log?date=$dateKey'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Failed with status ${response.statusCode}');
      }
      final payload = json.decode(response.body);
      final log = payload['log'];

      final nextCheckboxState = <String, bool>{};
      final nextExerciseCompleted = <String, bool>{};
      final nextMealQuantities = <String, Map<int, double>>{};
      int nextWater = 0;
      int nextSteps = 0;

      if (log is Map) {
        final loggedMeals = Map<String, dynamic>.from(
          log['loggedMealItems'] ?? {},
        );
        loggedMeals.forEach((key, value) {
          final normalizedKey = key.toString();
          nextCheckboxState[normalizedKey] = true;
          final parts = normalizedKey.split('-');
          if (parts.length >= 3) {
            final mealType = parts[1];
            final index = int.tryParse(parts.last) ?? 0;
            nextMealQuantities[mealType] = Map<int, double>.from(
              nextMealQuantities[mealType] ?? <int, double>{},
            );
            nextMealQuantities[mealType]![index] =
                (value as num?)?.toDouble() ?? 1.0;
          }
        });

        final loggedWorkout = Map<String, dynamic>.from(
          log['loggedWorkoutItems'] ?? {},
        );
        loggedWorkout.forEach((key, value) {
          nextExerciseCompleted[key.toString()] = value == true;
        });

        nextWater = (log['water'] as num?)?.toInt() ?? 0;
        nextSteps = (log['steps'] as num?)?.toInt() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _checkboxState = nextCheckboxState;
        _exerciseCompleted = nextExerciseCompleted;
        _mealItemQuantities = nextMealQuantities;
        _waterGlasses = nextWater;
        _steps = nextSteps;
        _planLogLoaded = true;
        _planLogLoading = false;
        _planLogError = null;
        _loadedForDate = dateKey;
      });
    } catch (e) {
      if (!mounted) return;
      // Do NOT fall back to stale local/cached state on failure - show a
      // retry affordance instead (surfaced in build()) so the member never
      // sees a checkbox that might actually belong to a previous day.
      setState(() {
        _planLogLoading = false;
        _planLogError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _syncPlanLogToServer() async {
    if (_todayPlan == null || _memberPlanLoading) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/member/plan-log'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(_buildPlanLogPayload()),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save your progress. Check your connection.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _syncPlanLogToServer,
          ),
        ),
      );
    }
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
        Icon(icon, color: color.withValues(alpha: 0.20), size: size),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // IndexedStack keeps this page's State alive across tab switches, so
    // this is also our cheapest hook for catching a day rollover that
    // happened while the app was open on another tab.
    _refreshIfDayChanged();
  }

  // Refresh button: reloads the personalised plan and its completion log.
  void _refreshPlan() async {
    setState(() {
      _planLogLoaded = false;
    });
    await _loadPersonalisedPlan();
  }

  @override
  Widget build(BuildContext context) {
    // Cheap day-rollover guard: build() runs far more often than the
    // lifecycle callback, so this catches a midnight rollover that happens
    // while this tab is the visible one (IndexedStack keeps this page's
    // State alive across tab switches, so didChangeDependencies alone
    // wouldn't fire again on a tab re-visit).
    _refreshIfDayChanged();

    final plan = _todayPlan;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasMeals = plan != null && (plan['meals'] as Map).isNotEmpty;
    final hasWorkout = plan != null && (plan['workout'] as Map).isNotEmpty;
    final isRestDay = plan != null && plan['isRestDay'] == true;
    final planReady = !_memberPlanLoading &&
        _memberPlanError == null &&
        !_planLogLoading &&
        plan != null;
    final dailyTargets = plan != null
        ? _dailyTargetsForPlan(plan)
        : {'calories': 1800.0, 'protein': 120.0, 'carbs': 220.0, 'fat': 60.0};
    double mealPercent = 0;
    double mealCalories = 0;
    double mealGoal = dailyTargets['calories'] ?? 1800;
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
                eyebrow: 'Today\'s Plan',
                title: 'Your plan is ready.',
                subtitle:
                    'Workout, meals, water, and steps stay in one clear view.',
                trailing: IconButton(
                  onPressed: _memberPlanLoading ? null : _refreshPlan,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
              const SizedBox(height: 18),
              if (_memberPlanError == '__onboarding_needed__')
                _buildBuildPlanPrompt(
                  context,
                  'Complete your fitness profile to get your personalised plan.',
                )
              else if (_memberPlanError != null)
                _buildEditorialState(
                  title: 'Your plan needs a fresh pull.',
                  message:
                      'We hit a snag while loading your meals and workouts (${_memberPlanError!}). Try one more refresh and we will bring everything back into place.',
                  buttonLabel: 'Refresh Plan',
                  onPressed: _refreshPlan,
                )
              else if (_memberPlanLoading)
                _buildEditorialLoadingState()
              else if (plan == null || (!hasMeals && !hasWorkout && !isRestDay))
                _buildBuildPlanPrompt(
                  context,
                  'Your personalised plan is waiting.',
                )
              else if (_planLogLoading)
                _buildEditorialLoadingState()
              else ...[
                if (_planLogError != null) ...[
                  _buildPlanLogRetryBanner(colorScheme),
                  const SizedBox(height: 18),
                ],
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialSectionHeading(
                        eyebrow: 'Membership',
                        title: 'Your current gym plan.',
                        subtitle: 'View your current plan. Your gym team handles renewals, changes, and payments.',
                      ),
                      const SizedBox(height: 14),
                      if (_membershipLoading)
                        SkeletonLoader.detail()
                      else if (_membershipError != null)
                        ErrorStateView(
                          title: 'Could not load your plan.',
                          message: _membershipError,
                          onRetry: _loadMembershipHub,
                        )
                      else ...[
                        Text(
                          (_membershipSummary?['planName'] ?? 'No active plan').toString(),
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Status: ${(_membershipSummary?['status'] ?? 'inactive').toString().replaceAll('_', ' ')}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (_membershipSummary?['renewalDueDate'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Renewal due: ${formatDateIN(_membershipSummary!['renewalDueDate'])}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Need renewal, upgrade, add-ons, or payment help? Visit your gym front desk. They update your membership in the web admin.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.46,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary.withValues(alpha: 0.24),
                                    colorScheme.primary.withValues(alpha: 0.1),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.local_fire_department_outlined,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${mealCalories.toStringAsFixed(0)} kcal logged',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${mealLeft.toStringAsFixed(0)} kcal left to hit today\'s target',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(mealPercent * 100).round()}%',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
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
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (isRestDay)
                  EditorialSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EditorialSectionHeading(
                          eyebrow: 'Coming Up Next',
                          title: 'Rest day.',
                          subtitle:
                              'No workout is scheduled today - recover and get ready for tomorrow.',
                        ),
                      ],
                    ),
                  )
                else
                EditorialSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EditorialSectionHeading(
                        eyebrow: 'Coming Up Next',
                        title: 'Your next workout is ready.',
                        subtitle: 'Scan it fast, then jump in.',
                      ),
                      const SizedBox(height: 14),
                      EditorialBlurImage(
                        height: 174,
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
                                height: 126,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 112,
                              top: 16,
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
                                  const SizedBox(height: 12),
                                  Text(
                                    _workoutHeadline(workout, workoutItems),
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
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
                      if (workoutItems.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text('Quick log', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 10),
                        ...List.generate(
                          math.min(workoutItems.length, 2),
                          (index) => Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  index == math.min(workoutItems.length, 2) - 1
                                  ? 0
                                  : 10,
                            ),
                            child: _buildWorkoutQuickLogCard(
                              plan,
                              workoutItems[index],
                              index,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: EditorialPrimaryButton(
                          label: 'Open Workout',
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
                        title: 'Meals for today.',
                        subtitle: 'Key meal info stays easy to scan.',
                      ),
                      const SizedBox(height: 18),
                      if (meals.isEmpty)
                        Text(
                          'No meal plan is set up for today yet.',
                          style: theme.textTheme.bodyMedium,
                        )
                      else ...[
                        ..._orderedMealKeysFromRaw(
                          Map<String, dynamic>.from(meals),
                        ).map(
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
                            onPressed: _goToMealDetail,
                          ),
                        ),
                      ],
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
                const SizedBox(height: 18),
                _buildProgressCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Card chrome shared by every block in this section, matching the
  // theme-aware surfaceContainerHigh pattern used elsewhere on this page
  // (EditorialSurface etc.) instead of a hardcoded Colors.white, which used
  // to render as a jarring, low-contrast bright box in dark mode.
  Widget _planCard(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _buildBuildPlanPrompt(BuildContext context, String title) {
    final theme = Theme.of(context);
    return _planCard(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Answer 8 quick questions and get a custom workout and meal plan.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MemberOnboardingPage()),
              );
              _loadPersonalisedPlan();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Build my plan →',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Single derived "today" view built from the new engine
  // (_memberWorkoutPlan/_memberMealPlan) - the source of truth for
  // everything this page renders. Shaped to match what the "Coming Up
  // Next"/"Meals Today" cards and the two logging bottom sheets already
  // expect, so their UI logic didn't need to change, only what feeds it.
  Map<String, dynamic>? get _todayPlan {
    if (_memberWorkoutPlan == null && _memberMealPlan == null) return null;

    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final now = DateTime.now();
    final dayIndex = now.weekday - 1; // 0=Mon...6=Sun
    final dayNum = now.weekday; // 1=Mon...7=Sun
    final dayName = dayNames[dayIndex];

    Map<String, dynamic> workout = {};
    bool isRestDay = false;
    if (_memberWorkoutPlan != null) {
      final daysPerWeek =
          (_memberWorkoutPlan!['daysPerWeek'] as num?)?.toInt() ?? 3;
      final schedules =
          _memberWorkoutPlan!['schedules'] as Map<String, dynamic>?;
      final schedule =
          (schedules?[daysPerWeek.toString()] as List<dynamic>?) ??
          (schedules?.values.firstOrNull as List<dynamic>?);
      final todayWorkoutId =
          (schedule != null && schedule.length == 7)
          ? schedule[dayIndex].toString()
          : 'rest';
      final workouts =
          (_memberWorkoutPlan!['workouts'] as List<dynamic>?) ?? [];
      final dynamic matched = todayWorkoutId == 'rest'
          ? null
          : workouts.firstWhere(
              (w) => w is Map && w['id'] == todayWorkoutId,
              orElse: () => null,
            );
      if (matched == null) {
        isRestDay = true;
      } else {
        final m = Map<String, dynamic>.from(matched as Map);
        workout = {
          'name': m['name'],
          'target': m['name'],
          'exercises': (m['exercises'] as List<dynamic>?) ?? [],
          'duration': 0,
          'calories': 0,
        };
      }
    }

    final meals = <String, dynamic>{};
    if (_memberMealPlan != null) {
      final days = (_memberMealPlan!['days'] as List<dynamic>?) ?? [];
      final dynamic todayMealsRaw = days.isEmpty
          ? null
          : days.firstWhere(
              (d) => d is Map && d['dayNumber'] == dayNum,
              orElse: () => days.first,
            );
      if (todayMealsRaw is Map) {
        final mealsList = (todayMealsRaw['meals'] as List<dynamic>?) ?? [];
        for (final rawMeal in mealsList) {
          if (rawMeal is! Map) continue;
          final type = (rawMeal['type'] ?? 'meal').toString();
          final items = (rawMeal['items'] as List<dynamic>?) ?? [];
          meals[type] = {
            'items': items.map((rawItem) {
              if (rawItem is! Map) return <String, dynamic>{};
              return {
                'name': rawItem['name'],
                'quantity': rawItem['portion'],
                'calories': rawItem['caloriesKcal'],
                'macros': {
                  'protein': rawItem['proteinG'],
                  'carbs': rawItem['carbsG'],
                  'fats': rawItem['fatG'],
                },
              };
            }).toList(),
          };
        }
      }
    }

    final macros = _memberMealPlan?['macros'] as Map<String, dynamic>?;

    return {
      'day': dayName,
      'workout': workout,
      'isRestDay': isRestDay,
      'meals': meals,
      'dailyTargets': {
        'calories': _asDouble(_memberMealPlan?['dailyCalories']),
        'protein': _asDouble(macros?['proteinG']),
        'carbs': _asDouble(macros?['carbsG']),
        'fat': _asDouble(macros?['fatG']),
      },
      'goal': _memberProfile?['goal'] ?? _memberWorkoutPlan?['goal'] ?? '',
    };
  }

  Widget _buildPlanLogRetryBanner(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Couldn't sync today's progress ($_planLogError).",
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _planLogLoaded = false);
              _hydratePlanLogForCurrentPlan();
            },
            child: const Text('Retry'),
          ),
        ],
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
            'We are pulling your meals, workout focus, and daily targets now.',
            style: Theme.of(context).textTheme.bodyMedium,
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
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
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
      return 'Open the workout to see today’s full session.';
    }
    final names = items
        .take(2)
        .map((item) => item['name']?.toString() ?? 'Move')
        .join(', ');
    return '$names${items.length > 2 ? ' and more' : ''} keep today moving.';
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
    final calories = _mealPlannedCalories(meal);
    final leadItem = items.isNotEmpty
        ? _mealItemAsMap(items.first)
        : <String, dynamic>{};
    final timeLabel = _mealTimeLabel(leadItem, mealType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            width: 46,
            height: 46,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _abc(mealType),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      timeLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${calories.toStringAsFixed(0)} kcal • ${items.length} items',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Text(
                    'Details will appear here once your meal is ready.',
                    style: theme.textTheme.bodySmall,
                  )
                else
                  ...List.generate(
                    1,
                    (index) => Padding(
                      padding: EdgeInsets.zero,
                      child: _buildMealQuickLogRow(
                        mealType,
                        index,
                        _mealItemAsMap(items[index]),
                      ),
                    ),
                  ),
                if (items.length > 2) ...[
                  const SizedBox(height: 10),
                  Text(
                    '+${items.length - 1} more item${items.length - 1 == 1 ? '' : 's'} in the full meal plan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealQuickLogRow(
    String mealType,
    int index,
    Map<String, dynamic> item,
  ) {
    final theme = Theme.of(context);
    final key = 'meal-$mealType-$index';
    final logged = _checkboxState[key] ?? false;
    final quantity = _mealItemQuantities[mealType]?[index] ?? 1.0;
    final macros = _mealMacroSummary(item);
    const quickOptions = [1.0, 1.5];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: logged
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: logged
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _toggleMealLogged(mealType, index, !logged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: logged
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    logged ? Icons.check_rounded : Icons.add_task_rounded,
                    size: 18,
                    color: logged
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mealPrimaryTitle(item),
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          _mealServingLine(item),
                          _mealTimeLabel(item, mealType),
                        ].where((part) => part.isNotEmpty).join(' • '),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (macros.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          macros,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickOptions.map((option) {
              final selected = (quantity - option).abs() < 0.01;
              return ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: Text(option == 1.0 ? '1x' : '1.5x'),
                selected: selected,
                onSelected: (_) => _updateMealQuantity(mealType, index, option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutQuickLogCard(
    Map<String, dynamic> plan,
    Map<String, dynamic> exercise,
    int index,
  ) {
    final theme = Theme.of(context);
    final exerciseKey = 'workout-ex-$index';
    final logged = _exerciseCompleted[exerciseKey] ?? false;
    final muscle =
        exercise['muscleGroup']?.toString() ??
        exercise['focus']?.toString() ??
        'session';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _toggleExerciseLogged(exerciseKey, !logged),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: logged
              ? theme.colorScheme.primary.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: logged
                ? theme.colorScheme.primary.withValues(alpha: 0.52)
                : theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: logged
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                logged ? Icons.check_rounded : Icons.fitness_center_rounded,
                size: 18,
                color: logged
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise['name']?.toString() ?? 'Exercise',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${exercise['sets'] ?? 0} sets • ${exercise['reps'] ?? 0} reps',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _abc(muscle),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: progressColor),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _TrackerControlButton(
                icon: Icons.remove_rounded,
                onPressed: onMinus,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress >= 1 ? 'Done' : 'Keep going',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 10),
              _TrackerControlButton(icon: Icons.add_rounded, onPressed: onPlus),
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

  void _toggleMealLogged(String mealType, int index, bool logged) {
    if (_todayPlan == null) return;
    final key = 'meal-$mealType-$index';
    setState(() {
      _checkboxState[key] = logged;
    });
    _persistCompletionChange();
  }

  void _updateMealQuantity(String mealType, int index, double quantity) {
    if (_todayPlan == null) return;
    final sanitized = quantity <= 0 ? 0.5 : quantity;
    setState(() {
      _mealItemQuantities[mealType] = Map<int, double>.from(
        _mealItemQuantities[mealType] ?? <int, double>{},
      );
      _mealItemQuantities[mealType]![index] = sanitized;
    });
    _persistCompletionChange();
  }

  void _toggleExerciseLogged(String exerciseKey, bool logged) {
    setState(() {
      _exerciseCompleted[exerciseKey] = logged;
    });
    _persistCompletionChange();
  }

  void _goToMealDetail() async {
    final plan = _todayPlan;
    if (plan == null || _memberPlanLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _MealLoggingSheet(
          plan: plan,
          checkboxState: _checkboxState,
          mealItemQuantities: _mealItemQuantities,
          dailyTargets: _dailyTargetsForPlan(plan),
          onToggleItem: _toggleMealLogged,
          onQuantityChanged: _updateMealQuantity,
          calculateDailyTotals: _calculateDailyTotals,
        ),
      ),
    );
  }

  void _goToWorkoutDetail() async {
    final plan = _todayPlan;
    if (plan == null || _memberPlanLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan is still loading. Please wait.')),
      );
      return;
    }
    final workoutRaw = plan['workout'];
    final workout = workoutRaw is Map
        ? workoutRaw as Map<String, dynamic>
        : <String, dynamic>{};
    final exercises = _workoutPreviewItems(workout);
    final exerciseKeys = List.generate(
      exercises.length,
      (i) => 'workout-ex-$i',
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.94,
        child: _WorkoutLoggingSheet(
          plan: plan,
          exerciseKeys: exerciseKeys,
          exerciseCompleted: _exerciseCompleted,
          onToggleExercise: _toggleExerciseLogged,
          calculateWorkoutSummary: _calculateWorkoutSummary,
        ),
      ),
    );
  }

  void _editOnboarding() {
    MainNavigationScaffold.switchTab(3);
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
              title: 'We could not load the details shaping your plan.',
              subtitle: 'Try again to bring your snapshot back in view.',
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: EditorialPrimaryButton(
                label: 'Retry Snapshot',
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
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSectionHeading(
            eyebrow: 'Profile Snapshot',
            title: 'The details guiding your plan.',
            subtitle:
                'A quick read on the profile settings shaping your food and training rhythm today.',
            trailing: IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Open profile',
              onPressed: _editOnboarding,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildCompactSnapshotTile(
                  icon: Icons.cake_outlined,
                  label: 'Age',
                  value: '${profile['age'] ?? '-'}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactSnapshotTile(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: '${profile['weight'] ?? '-'} kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildCompactSnapshotTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Gender',
                  value: _abc(profile['gender']?.toString()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactSnapshotTile(
                  icon: Icons.height_rounded,
                  label: 'Height',
                  value: '${profile['height'] ?? '-'} cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProfileContextPanel(
            icon: Icons.flag_rounded,
            title: 'Goals',
            subtitle: 'What this plan is built to support',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fitnessGoals.isEmpty
                  ? [_buildProfileChip('Balanced training')]
                  : fitnessGoals
                        .map((goal) => _buildProfileChip(_abc(goal)))
                        .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _buildProfileContextPanel(
            icon: Icons.restaurant_menu_rounded,
            title: 'Diet context',
            subtitle: 'Food settings shaping today’s meals',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildContextStat(
                        'Diet',
                        _abc(dietPreferences['type']?.toString()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildContextStat(
                        'Meals',
                        '${dietPreferences['dailyMeals'] ?? '-'} daily',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildContextStat(
                        'Water',
                        '${dietPreferences['waterIntake'] ?? '-'} glasses',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildContextStat(
                        'Allergies',
                        _listSummary(dietPreferences['allergies']),
                      ),
                    ),
                  ],
                ),
                if (_listSummary(dietPreferences['restrictions']) !=
                    'None') ...[
                  const SizedBox(height: 10),
                  _buildContextStat(
                    'Restrictions',
                    _listSummary(dietPreferences['restrictions']),
                    fullWidth: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSnapshotTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
        ],
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

  Widget _buildProfileContextPanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildContextStat(
    String label,
    String value, {
    bool fullWidth = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _listSummary(dynamic value) {
    if (value is! List || value.isEmpty) return 'None';
    return value.map((item) => _abc(item.toString())).join(', ');
  }

  Map<String, dynamic> _mealItemAsMap(dynamic item) {
    if (item is Map) return Map<String, dynamic>.from(item);
    return <String, dynamic>{};
  }

  String _mealPrimaryTitle(Map<String, dynamic> item) {
    final name = item['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Meal details ready';
  }

  String _mealServingLine(Map<String, dynamic> item) {
    final quantity = item['quantity']?.toString().trim();
    if (quantity != null && quantity.isNotEmpty) return quantity;
    return '';
  }

  String _mealTimeLabel(Map<String, dynamic> item, String fallbackMealType) {
    final raw = item['time']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return _abc(fallbackMealType);
  }

  String _mealMacroSummary(Map<String, dynamic> item) {
    final macros = item['macros'];
    if (macros is! Map) return '';
    String formatMacro(dynamic raw) {
      final value = (raw as num?)?.toDouble() ?? 0.0;
      if ((value - value.roundToDouble()).abs() < 0.05) {
        return value.round().toString();
      }
      return value.toStringAsFixed(1);
    }

    final protein = macros['protein'] ?? macros['p'];
    final carbs = macros['carbs'] ?? macros['c'];
    final fats = macros['fats'] ?? macros['f'];
    final parts = <String>[];
    if (protein != null) parts.add('P ${formatMacro(protein)}g');
    if (carbs != null) parts.add('C ${formatMacro(carbs)}g');
    if (fats != null) parts.add('F ${formatMacro(fats)}g');
    return parts.join(' • ');
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
        final message = e.toString().toLowerCase();
        _progressError =
            message.contains('403') ||
                message.contains('expired token') ||
                message.contains('session')
            ? 'Your session expired. Please log in again.'
            : 'We could not load your profile details right now.';
        _progressLoading = false;
      });
    }
  }

  // Persist water and steps to SharedPreferences
  Future<void> _saveWaterAndSteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('plan_water_glasses', _waterGlasses);
    await prefs.setInt('plan_steps', _steps);
    _syncPlanLogToServer();
  }

  Future<void> _loadWaterAndSteps() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _waterGlasses = prefs.getInt('plan_water_glasses') ?? 0;
      _steps = prefs.getInt('plan_steps') ?? 0;
    });
  }
}

class _TrackerControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _TrackerControlButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _PlanSheetShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  const _PlanSheetShell({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: EditorialBackdrop(
        safeTop: false,
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: EditorialSectionHeading(
                                eyebrow: eyebrow,
                                title: title,
                                subtitle: subtitle,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        child,
                      ],
                    ),
                  ),
                ),
                if (footer != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: footer!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealLoggingSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final Map<String, bool> checkboxState;
  final Map<String, Map<int, double>> mealItemQuantities;
  final Map<String, double> dailyTargets;
  final void Function(String mealType, int index, bool logged) onToggleItem;
  final void Function(String mealType, int index, double quantity)
  onQuantityChanged;
  final Map<String, double> Function(Map<String, dynamic> plan)
  calculateDailyTotals;

  const _MealLoggingSheet({
    required this.plan,
    required this.checkboxState,
    required this.mealItemQuantities,
    required this.dailyTargets,
    required this.onToggleItem,
    required this.onQuantityChanged,
    required this.calculateDailyTotals,
  });

  @override
  State<_MealLoggingSheet> createState() => _MealLoggingSheetState();
}

class _MealLoggingSheetState extends State<_MealLoggingSheet> {
  static const List<double> _quantityOptions = [0.5, 1.0, 1.5, 2.0];

  double _itemCalories(Map<String, dynamic> item) {
    final directCal =
        (item['calories'] as num?)?.toDouble() ??
        (item['cal'] as num?)?.toDouble();
    if (directCal != null && directCal > 0) return directCal;

    final macros = item['macros'];
    if (macros is Map) {
      final protein =
          (macros['protein'] as num?)?.toDouble() ??
          (macros['p'] as num?)?.toDouble() ??
          0.0;
      final carbs =
          (macros['carbs'] as num?)?.toDouble() ??
          (macros['c'] as num?)?.toDouble() ??
          0.0;
      final fats =
          (macros['fats'] as num?)?.toDouble() ??
          (macros['f'] as num?)?.toDouble() ??
          0.0;
      return (protein * 4) + (carbs * 4) + (fats * 9);
    }

    return 0;
  }

  double _mealPlannedCalories(Map meal) {
    if (meal['cal'] is num) return (meal['cal'] as num).toDouble();
    final items = meal['items'] is List
        ? List<dynamic>.from(meal['items'])
        : [];
    return items
        .map((item) => _itemCalories(_planMealItemAsMap(item)))
        .fold<double>(0, (sum, value) => sum + value);
  }

  String _quantityLabel(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value == 1 ? '1x' : '${value.toInt()}x';
    }
    return '${value.toStringAsFixed(1)}x';
  }

  Widget _macroBlock(
    BuildContext context,
    String label,
    double current,
    double goal,
    Color color,
  ) {
    final percent = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 6),
            Text(
              '${current.toStringAsFixed(0)} / ${goal.toStringAsFixed(0)} g',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyTotals = widget.calculateDailyTotals(widget.plan);
    final calorieGoal = widget.dailyTargets['calories'] ?? 1800;
    final calorieProgress = calorieGoal > 0
        ? (dailyTotals['cal']! / calorieGoal).clamp(0.0, 1.0)
        : 0.0;
    final caloriesLeft = (calorieGoal - dailyTotals['cal']!).clamp(
      0.0,
      calorieGoal,
    );
    final meals = widget.plan['meals'] is Map
        ? Map<String, dynamic>.from(widget.plan['meals'] as Map)
        : <String, dynamic>{};

    return _PlanSheetShell(
      eyebrow: 'Meal Plan',
      title: 'Log meals without losing your place.',
      subtitle:
          'Tick off what you ate, adjust the portion, and watch your daily totals move right away.',
      footer: SizedBox(
        width: double.infinity,
        child: EditorialPrimaryButton(
          label: 'Done Logging',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dailyTotals['cal']!.toStringAsFixed(0)} / ${calorieGoal.toStringAsFixed(0)} kcal',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  caloriesLeft <= 0
                      ? 'Target reached. Nice work staying on pace.'
                      : '${caloriesLeft.toStringAsFixed(0)} kcal left for today.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: calorieProgress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _macroBlock(
                      context,
                      'Protein',
                      dailyTotals['p']!,
                      widget.dailyTargets['protein'] ?? 120,
                      theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    _macroBlock(
                      context,
                      'Carbs',
                      dailyTotals['c']!,
                      widget.dailyTargets['carbs'] ?? 220,
                      theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    _macroBlock(
                      context,
                      'Fat',
                      dailyTotals['f']!,
                      widget.dailyTargets['fat'] ?? 60,
                      theme.colorScheme.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ..._orderedMealKeysFromRaw(Map<String, dynamic>.from(meals)).map((
            mealType,
          ) {
            final meal = meals[mealType] is Map
                ? Map<String, dynamic>.from(meals[mealType] as Map)
                : <String, dynamic>{};
            final items = meal['items'] is List
                ? List<dynamic>.from(meal['items'])
                : <dynamic>[];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EditorialSurface(
                padding: const EdgeInsets.all(18),
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _planMealIcon(mealType),
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _planFriendlyLabel(mealType),
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_mealPlannedCalories(meal).toStringAsFixed(0)} kcal planned',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...List.generate(items.length, (index) {
                      final item = _planMealItemAsMap(items[index]);
                      final itemKey = 'meal-$mealType-$index';
                      final logged = widget.checkboxState[itemKey] ?? false;
                      final quantity =
                          widget.mealItemQuantities[mealType]?[index] ?? 1.0;
                      final macros = _planMealMacroSummary(item);
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == items.length - 1 ? 0 : 12,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            widget.onToggleItem(mealType, index, !logged);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: logged
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.16,
                                    )
                                  : theme.colorScheme.surfaceContainerHigh
                                        .withValues(alpha: 0.52),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: logged
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.55,
                                      )
                                    : theme.colorScheme.outline.withValues(
                                        alpha: 0.18,
                                      ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: logged
                                            ? theme.colorScheme.primary
                                            : theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        logged
                                            ? Icons.check_rounded
                                            : Icons.add_task_rounded,
                                        size: 18,
                                        color: logged
                                            ? theme.colorScheme.onPrimary
                                            : theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _planMealPrimaryTitle(item),
                                            style: theme.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                                  _planMealServingLine(item),
                                                  _planMealTimeLabel(
                                                    item,
                                                    mealType,
                                                  ),
                                                ]
                                                .where(
                                                  (part) => part.isNotEmpty,
                                                )
                                                .join(' • '),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          if (macros.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              macros,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _quantityOptions.map((option) {
                                    final selected =
                                        (quantity - option).abs() < 0.01;
                                    return ChoiceChip(
                                      label: Text(_quantityLabel(option)),
                                      selected: selected,
                                      onSelected: (_) {
                                        widget.onQuantityChanged(
                                          mealType,
                                          index,
                                          option,
                                        );
                                        setState(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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

class _WorkoutLoggingSheet extends StatefulWidget {
  final Map<String, dynamic> plan;
  final List<String> exerciseKeys;
  final Map<String, bool> exerciseCompleted;
  final void Function(String exerciseKey, bool logged) onToggleExercise;
  final Map<String, dynamic> Function(Map<String, dynamic> plan)
  calculateWorkoutSummary;

  const _WorkoutLoggingSheet({
    required this.plan,
    required this.exerciseKeys,
    required this.exerciseCompleted,
    required this.onToggleExercise,
    required this.calculateWorkoutSummary,
  });

  @override
  State<_WorkoutLoggingSheet> createState() => _WorkoutLoggingSheetState();
}

class _WorkoutLoggingSheetState extends State<_WorkoutLoggingSheet> {
  List<MapEntry<String, List<Map<String, dynamic>>>> _exerciseGroups() {
    final workout = widget.plan['workout'] is Map
        ? Map<String, dynamic>.from(widget.plan['workout'] as Map)
        : <String, dynamic>{};
    final exercisesRaw = workout['exercises'];
    if (exercisesRaw is List) {
      return [MapEntry('Session', exercisesRaw.map(parseExercise).toList())];
    }
    if (exercisesRaw is Map) {
      return exercisesRaw.entries.map((entry) {
        final group = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{};
        final items = group['items'] is List
            ? List<dynamic>.from(group['items']).map(parseExercise).toList()
            : <Map<String, dynamic>>[];
        final label =
            group['muscleGroup']?.toString() ?? _planFriendlyLabel(entry.key);
        return MapEntry(label, items);
      }).toList();
    }
    return <MapEntry<String, List<Map<String, dynamic>>>>[];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workout = widget.plan['workout'] is Map
        ? Map<String, dynamic>.from(widget.plan['workout'] as Map)
        : <String, dynamic>{};
    final summary = widget.calculateWorkoutSummary(widget.plan);
    final groups = _exerciseGroups();

    return _PlanSheetShell(
      eyebrow: 'Workout',
      title: 'Log your session while it is still in motion.',
      subtitle:
          'Mark each move as you finish it and your plan summary will stay in sync behind the sheet.',
      footer: SizedBox(
        width: double.infinity,
        child: EditorialPrimaryButton(
          label: 'Close Workout',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout['target']?.toString().trim().isNotEmpty == true
                      ? workout['target'].toString()
                      : 'Today\'s training block',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: EditorialMetricTile(
                        label: 'Duration',
                        value:
                            '${(summary['duration'] as num?)?.round() ?? 0} min',
                        icon: Icons.timer_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EditorialMetricTile(
                        label: 'Calories',
                        value:
                            '${(summary['calories'] as num?)?.round() ?? 0} kcal',
                        icon: Icons.local_fire_department_outlined,
                        iconColor: theme.colorScheme.tertiary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EditorialMetricTile(
                        label: 'Done',
                        value: '${summary['completed']}/${summary['total']}',
                        icon: Icons.check_circle_outline_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: (summary['progress'] as num?)?.toDouble() ?? 0.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...groups.asMap().entries.map((groupEntry) {
            final groupIndex = groupEntry.key;
            final group = groupEntry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: EditorialSurface(
                padding: const EdgeInsets.all(18),
                radius: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.key, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...group.value.asMap().entries.map((exerciseEntry) {
                      final exerciseIndex = exerciseEntry.key;
                      final exercise = exerciseEntry.value;
                      final globalIndex =
                          groups
                              .take(groupIndex)
                              .fold<int>(
                                0,
                                (sum, item) => sum + item.value.length,
                              ) +
                          exerciseIndex;
                      final exerciseKey = widget.exerciseKeys[globalIndex];
                      final logged =
                          widget.exerciseCompleted[exerciseKey] ?? false;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: exerciseIndex == group.value.length - 1
                              ? 0
                              : 12,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () {
                            widget.onToggleExercise(exerciseKey, !logged);
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: logged
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.16,
                                    )
                                  : theme.colorScheme.surfaceContainerHigh
                                        .withValues(alpha: 0.54),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: logged
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.55,
                                      )
                                    : theme.colorScheme.outline.withValues(
                                        alpha: 0.18,
                                      ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: logged
                                        ? theme.colorScheme.primary
                                        : theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    logged
                                        ? Icons.check_rounded
                                        : Icons.fitness_center_rounded,
                                    size: 18,
                                    color: logged
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        exercise['name']?.toString() ??
                                            'Exercise',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${exercise['sets'] ?? 0} sets • ${exercise['reps'] ?? 0} reps',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        exercise['muscleGroup']?.toString() ??
                                            group.key,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
