import 'package:flutter/foundation.dart';
import 'package:gymmate_mobile/models/user_progress_model.dart';
import 'package:gymmate_mobile/services/onboarding_service.dart';

class OnboardingProvider with ChangeNotifier {
  OnboardingService? _onboardingService;
  bool _isInitializing = false;

  String? _token;
  String? _userId;

  // State properties
  bool _isLoading = false;
  bool _isCompleted = false;
  int _currentStep = 1;
  final int _totalSteps = 7; // Define total steps
  double _progress = 0.0;
  String? _error;
  
  // Gamification properties
  int _totalXP = 0;
  int _level = 1;
  List<Badge> _badges = [];
  String? _lastBadgeUnlocked;

  // Getters
  bool get isLoading => _isLoading;
  bool get isCompleted => _isCompleted;
  int get currentStep => _currentStep;
  double get progress => _progress;
  String? get error => _error;
  int get totalXP => _totalXP;
  int get level => _level;
  List<Badge> get badges => _badges;
  String? get lastBadgeUnlocked => _lastBadgeUnlocked;
  String? get userId => _userId;
  String? get token => _token;

  void update(String? token, String? userId) {
    _token = token;
    _userId = userId;
    _onboardingService = OnboardingService(token);
    // We could potentially trigger a fetch here if needed when auth state changes
    // For now, we just update the internal state.
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitializing) {
      print('⚠️ OnboardingProvider: Already initializing, skipping');
      return;
    }
    
    if (_onboardingService == null) {
      print('⚠️ OnboardingService not initialized, skipping initialization');
      return;
    }
    
    _isInitializing = true;
    _setLoading(true);
    _setError(null);
    
    try {
      print('🔄 OnboardingProvider: Starting initialization');
      final status = await _onboardingService!.getOnboardingStatus();
      _isCompleted = status['isCompleted'] ?? false;
      _currentStep = status['currentStep'] ?? 1;
      _progress = (status['progress'] ?? 0.0).toDouble();

      if (_isCompleted) {
        _currentStep = _totalSteps;
        _progress = 100.0;
      }
      
      await fetchUserProgress();
      print('✅ OnboardingProvider: Initialization completed');

    } catch (e) {
      print('❌ OnboardingProvider.initialize() error: $e');
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _isInitializing = false;
    }
  }

  Future<void> nextStep() async {
    if (_currentStep < _totalSteps) {
      _currentStep++;
      notifyListeners();
    } else if (_currentStep == _totalSteps) {
      await completeOnboarding();
    }
  }

  void previousStep() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  Future<void> saveStepProgress(int step, Map<String, dynamic> data) async {
    if (_onboardingService == null) {
      print('⚠️ OnboardingService not initialized, cannot save step progress');
      return;
    }
    
    _setLoading(true);
    try {
      final result = await _onboardingService!.saveStepProgress(step, data);
      _updateStateFromResult(result);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
  
  Future<void> completeOnboarding() async {
    if (_onboardingService == null) {
      print('⚠️ OnboardingService not initialized, cannot complete onboarding');
      return;
    }
    
    _setLoading(true);
    try {
      final result = await _onboardingService!.completeOnboarding();
      _updateStateFromResult(result);
      _isCompleted = true;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchUserProgress() async {
    if (_onboardingService == null) {
      print('⚠️ OnboardingService not initialized, cannot fetch user progress');
      return;
    }
    
    _setLoading(true);
    try {
      final data = await _onboardingService!.getUserProgress();
      final userProgress = UserProgress.fromJson(data);
      _totalXP = userProgress.totalXP;
      _level = userProgress.level;
      _badges = userProgress.badges;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  void _updateStateFromResult(Map<String, dynamic> result) {
    _currentStep = result['currentStep'] ?? _currentStep;
    _progress = (result['progress'] ?? _progress).toDouble();
    _isCompleted = result['isCompleted'] ?? _isCompleted;
    _totalXP = result['totalXP'] ?? _totalXP;
    _level = result['level'] ?? _level;

    if (result['badgeUnlocked'] != null) {
      final badgeData = result['badgeUnlocked'];
      final newBadge = Badge.fromJson(badgeData);
      if (!_badges.any((b) => b.id == newBadge.id)) {
        _badges.add(newBadge);
        _lastBadgeUnlocked = newBadge.name;
      }
    }
    notifyListeners();
  }
}