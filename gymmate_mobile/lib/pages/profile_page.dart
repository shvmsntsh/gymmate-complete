import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../utils/gallery_picker.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../utils/role_utils.dart';
import '../widgets/confetti_success.dart';
import '../widgets/editorial_mobile.dart';
import 'gamified_entry_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _dailyMealsController;
  late TextEditingController _waterIntakeController;
  late TextEditingController _allergiesController;
  late TextEditingController _restrictionsController;
  late TextEditingController _workoutsPerWeekController;
  late TextEditingController _sessionDurationController;
  late TextEditingController _injuryDetailsController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  bool _isSaving = false;
  bool _showConfetti = false;
  bool _memberDetailsLoading = false;
  String? _memberDetailsError;
  String? _editingSection;
  String? _savingSection;
  Map<String, dynamic>? _savedMemberData;
  Map<String, dynamic>? _draftMemberData;
  bool _isUploadingProfilePicture = false;
  bool _isSavingPassword = false;
  bool _isSavingAvatar = false;

  static const List<(String, String)> _goalOptions = [
    ('Build Muscle', 'muscle_gain'),
    ('Fat Loss', 'fat_loss'),
    ('General Fitness', 'general_fitness'),
    ('Performance', 'performance'),
    ('Strength', 'strength'),
    ('Endurance', 'endurance'),
  ];

  static const List<(String, String)> _dietTypes = [
    ('Vegetarian', 'vegetarian'),
    ('Vegan', 'vegan'),
    ('Non-Vegetarian', 'non_vegetarian'),
    ('Flexible', 'flexible'),
  ];

  static const List<(String, String)> _activityLevels = [
    ('Sedentary', 'sedentary'),
    ('Lightly Active', 'lightly_active'),
    ('Moderately Active', 'moderately_active'),
    ('Very Active', 'very_active'),
    ('Extremely Active', 'extremely_active'),
  ];

  static const List<(String, String)> _preferredTimes = [
    ('Early Morning', 'early_morning'),
    ('Morning', 'morning'),
    ('Afternoon', 'afternoon'),
    ('Evening', 'evening'),
    ('Night', 'night'),
    ('Flexible', 'flexible'),
  ];

  static const List<(String, String)> _exerciseTypes = [
    ('Cardio', 'cardio'),
    ('Weight Training', 'weight_training'),
    ('Yoga', 'yoga'),
    ('Swimming', 'swimming'),
    ('CrossFit', 'crossfit'),
  ];

  static const List<(String, String)> _challengeTypes = [
    ('7-Day Check-in', '7_day_checkin'),
    ('First Workout', 'first_workout'),
    ('Meal Rhythm', 'meal_rhythm'),
  ];

  static const List<(String, String)> _genderOptions = [
    ('Male', 'male'),
    ('Female', 'female'),
    ('Non-Binary', 'non_binary'),
    ('Prefer Not To Say', 'prefer_not_to_say'),
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: authProvider.userName ?? '');
    _emailController = TextEditingController(
      text: authProvider.userEmail ?? '',
    );
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _dailyMealsController = TextEditingController();
    _waterIntakeController = TextEditingController();
    _allergiesController = TextEditingController();
    _restrictionsController = TextEditingController();
    _workoutsPerWeekController = TextEditingController();
    _sessionDurationController = TextEditingController();
    _injuryDetailsController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    final normalizedRole =
        normalizeRole(
          authProvider.userData?['role'] as String? ?? authProvider.userRole,
        ) ??
        '';
    if (isMemberRole(normalizedRole)) {
      _loadMemberDetails();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _dailyMealsController.dispose();
    _waterIntakeController.dispose();
    _allergiesController.dispose();
    _restrictionsController.dispose();
    _workoutsPerWeekController.dispose();
    _sessionDurationController.dispose();
    _injuryDetailsController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

  Widget _buildAvatarImage(String path, double size) {
    if (path.startsWith('data:')) {
      final base64Str = path.replaceFirst(
        RegExp(r'^data:image/\w+;base64,'),
        '',
      );
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          Icons.person_outline_rounded,
          size: size * 0.5,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Image.asset(path, fit: BoxFit.cover, width: size, height: size);
  }

  String? _validateEmail(String? value) {
    if (value == null || !RegExp(r'^\S+@\S+\.\S+').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _loadMemberDetails() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    setState(() {
      _memberDetailsLoading = true;
      _memberDetailsError = null;
    });

    try {
      final service = OnboardingService()..setToken(token);
      final data = await service.getUserProgress();
      final normalized = _normalizeMemberData(data);
      if (!mounted) return;
      setState(() {
        _savedMemberData = normalized;
        _draftMemberData = _cloneMap(normalized);
        _memberDetailsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _memberDetailsError = _friendlyMemberDetailsError(e.toString());
        _memberDetailsLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final nameError = _validateName(name);
    final emailError = _validateEmail(email);
    if (nameError != null || emailError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(nameError ?? emailError!)));
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final authService = AuthService();
      final response = await authService.updateProfile(
        name: name,
        email: email,
        token: token,
      );
      await authProvider.applySessionUpdate(response);
      if (!mounted) return;
      _celebrateSave('Profile updated successfully.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<(String, String)> _avatarOptionsForRole(String role) {
    switch (normalizeRole(role)) {
      case 'owner':
        return const [('Owner M', 'assets/avatars/o_m_1.png'), ('Owner F', 'assets/avatars/o_f_1.png')];
      case 'trainer':
        return const [('Trainer M', 'assets/avatars/t_m_1.png'), ('Trainer F', 'assets/avatars/t_f_1.png')];
      case 'member':
        return const [('Member M', 'assets/avatars/m_m_1.png'), ('Member F', 'assets/avatars/m_f_1.png')];
      case 'staff':
      case 'admin':
        return const [('Staff M', 'assets/avatars/staff_m_1.png'), ('Staff F', 'assets/avatars/staff_f_1.png')];
      default:
        return const [('Member M', 'assets/avatars/m_m_1.png'), ('Member F', 'assets/avatars/m_f_1.png')];
    }
  }

  Future<void> _chooseRoleAvatar(AuthProvider authProvider, String avatar) async {
    setState(() => _isSavingAvatar = true);
    try {
      await authProvider.setAvatarPath(avatar);
      if (!mounted) return;
      _celebrateSave('Avatar updated.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSavingAvatar = false);
    }
  }

  Future<void> _savePassword(AuthProvider authProvider) async {
    final hasPassword = authProvider.userData?['hasPassword'] == true;
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (hasPassword && current.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is required.')),
      );
      return;
    }
    if (next.length < 6 || next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords must match and use at least 6 characters.')),
      );
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      await AuthService().changePassword(
        currentPassword: hasPassword ? current : null,
        newPassword: next,
        token: authProvider.token,
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      await authProvider.refreshUser();
      if (!mounted) return;
      _celebrateSave('Password updated.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _saveMemberSection(String section) async {
    if (_draftMemberData == null) return;

    final validationError = _applyDraftSectionValues(section);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session expired. Please log in again.'),
        ),
      );
      return;
    }

    setState(() {
      _savingSection = section;
    });

    try {
      final service = OnboardingService()..setToken(token);
      await service.completeOnboarding(
        _buildOnboardingPayload(_draftMemberData!),
      );
      await authProvider.completeOnboarding();
      if (!mounted) return;
      setState(() {
        _savedMemberData = _cloneMap(_draftMemberData!);
        _editingSection = null;
        _savingSection = null;
      });
      _celebrateSave('Profile details updated.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _savingSection = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update details: ${e.toString()}')),
      );
    }
  }

  void _celebrateSave(String message) {
    setState(() => _showConfetti = true);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _showConfetti = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _beginEdit(String section) {
    if (_savedMemberData == null) return;
    setState(() {
      _editingSection = section;
      _draftMemberData = _cloneMap(_savedMemberData!);
      _memberDetailsError = null;
    });
    _seedControllers(section);
  }

  void _cancelEdit() {
    setState(() {
      _editingSection = null;
      if (_savedMemberData != null) {
        _draftMemberData = _cloneMap(_savedMemberData!);
      }
    });
  }

  void _seedControllers(String section) {
    final draft = _draftMemberData;
    if (draft == null) return;

    if (section == 'profile') {
      final profile = Map<String, dynamic>.from(draft['profile'] ?? {});
      _ageController.text = _numberOrBlank(profile['age']);
      _weightController.text = _numberOrBlank(profile['weight']);
      _heightController.text = _numberOrBlank(profile['height']);
    } else if (section == 'diet') {
      final prefs = Map<String, dynamic>.from(draft['dietPreferences'] ?? {});
      _dailyMealsController.text = _numberOrBlank(prefs['dailyMeals']);
      _waterIntakeController.text = _numberOrBlank(prefs['waterIntake']);
      _allergiesController.text = _joinCsv(prefs['allergies']);
      _restrictionsController.text = _joinCsv(prefs['restrictions']);
    } else if (section == 'workout') {
      final habits = Map<String, dynamic>.from(draft['workoutHabits'] ?? {});
      _workoutsPerWeekController.text = _numberOrBlank(
        habits['workoutsPerWeek'],
      );
      _sessionDurationController.text = _numberOrBlank(
        habits['sessionDuration'],
      );
      _injuryDetailsController.text = (habits['injuryDetails'] ?? '')
          .toString();
    }
  }

  String? _applyDraftSectionValues(String section) {
    final draft = _draftMemberData;
    if (draft == null) return 'Profile details are not ready yet.';

    if (section == 'profile') {
      final age = int.tryParse(_ageController.text.trim());
      final weight = double.tryParse(_weightController.text.trim());
      final height = double.tryParse(_heightController.text.trim());
      if (age == null || age <= 0) return 'Enter a valid age.';
      if (weight == null || weight <= 0) return 'Enter a valid weight.';
      if (height == null || height <= 0) return 'Enter a valid height.';
      final profile = Map<String, dynamic>.from(draft['profile'] ?? {});
      profile['age'] = age;
      profile['weight'] = weight;
      profile['height'] = height;
      draft['profile'] = profile;
      return null;
    }

    if (section == 'goals') {
      final goals = List<String>.from(
        draft['fitnessGoals'] ?? const <String>[],
      );
      if (goals.isEmpty) return 'Choose at least one fitness goal.';
      return null;
    }

    if (section == 'diet') {
      final meals = int.tryParse(_dailyMealsController.text.trim());
      final water = int.tryParse(_waterIntakeController.text.trim());
      if (meals == null || meals <= 0)
        return 'Enter a valid daily meals count.';
      if (water == null || water <= 0) return 'Enter a valid water intake.';
      final prefs = Map<String, dynamic>.from(draft['dietPreferences'] ?? {});
      prefs['dailyMeals'] = meals;
      prefs['waterIntake'] = water;
      prefs['allergies'] = _splitCsv(_allergiesController.text);
      prefs['restrictions'] = _splitCsv(_restrictionsController.text);
      draft['dietPreferences'] = prefs;
      return null;
    }

    if (section == 'workout') {
      final workouts = int.tryParse(_workoutsPerWeekController.text.trim());
      final duration = int.tryParse(_sessionDurationController.text.trim());
      if (workouts == null || workouts <= 0) {
        return 'Enter valid workouts per week.';
      }
      if (duration == null || duration <= 0) {
        return 'Enter a valid session duration.';
      }
      final habits = Map<String, dynamic>.from(draft['workoutHabits'] ?? {});
      habits['workoutsPerWeek'] = workouts;
      habits['sessionDuration'] = duration;
      final hasInjuries = habits['hasInjuries'] == true;
      habits['injuryDetails'] = hasInjuries
          ? _injuryDetailsController.text.trim()
          : null;
      draft['workoutHabits'] = habits;
      return null;
    }

    return null;
  }

  Map<String, dynamic> _buildOnboardingPayload(Map<String, dynamic> source) {
    return {
      'profile': Map<String, dynamic>.from(source['profile'] ?? {}),
      'fitnessGoals': List<String>.from(
        source['fitnessGoals'] ?? const <String>[],
      ),
      'dietPreferences': Map<String, dynamic>.from(
        source['dietPreferences'] ?? {},
      ),
      'workoutHabits': Map<String, dynamic>.from(source['workoutHabits'] ?? {}),
      'firstChallenge': Map<String, dynamic>.from(
        source['firstChallenge'] ?? {},
      ),
    };
  }

  Map<String, dynamic> _normalizeMemberData(Map<String, dynamic> raw) {
    final profile = Map<String, dynamic>.from(raw['profile'] ?? {});
    final dietPreferences = Map<String, dynamic>.from(
      raw['dietPreferences'] ?? {},
    );
    final workoutHabits = Map<String, dynamic>.from(
      raw['workoutHabits'] ?? raw['workoutPreferences'] ?? {},
    );
    final challenge = Map<String, dynamic>.from(raw['firstChallenge'] ?? {});

    return {
      ...raw,
      'profile': {
        'age': profile['age'] ?? 0,
        'gender': profile['gender'],
        'weight': profile['weight'] ?? 0,
        'height': profile['height'] ?? 0,
      },
      'fitnessGoals': List<String>.from(
        raw['fitnessGoals'] ?? const <String>[],
      ),
      'dietPreferences': {
        'type': dietPreferences['type'] ?? 'flexible',
        'dailyMeals': dietPreferences['dailyMeals'] ?? 3,
        'waterIntake': dietPreferences['waterIntake'] ?? 8,
        'allergies': List<String>.from(
          dietPreferences['allergies'] ?? const <String>[],
        ),
        'restrictions': List<String>.from(
          dietPreferences['restrictions'] ?? const <String>[],
        ),
      },
      'workoutHabits': {
        'preferredTime': workoutHabits['preferredTime'] ?? 'flexible',
        'currentActivityLevel':
            workoutHabits['currentActivityLevel'] ?? 'moderately_active',
        'favoriteExercises': List<String>.from(
          workoutHabits['favoriteExercises'] ?? const <String>[],
        ),
        'workoutsPerWeek': workoutHabits['workoutsPerWeek'] ?? 3,
        'sessionDuration': workoutHabits['sessionDuration'] ?? 60,
        'hasInjuries': workoutHabits['hasInjuries'] ?? false,
        'injuryDetails': workoutHabits['injuryDetails'],
      },
      'firstChallenge': {
        'isAccepted': challenge['isAccepted'] ?? false,
        'type': challenge['type'] ?? '7_day_checkin',
        'startDate': challenge['startDate'],
        'endDate': challenge['endDate'],
        'progress': challenge['progress'] ?? 0,
        'current': challenge['current'],
        'target': challenge['target'],
        'summary': challenge['summary'],
        'nextStep': challenge['nextStep'],
        'status': challenge['status'],
        'statusLabel': challenge['statusLabel'],
        'isCompleted': challenge['isCompleted'] ?? false,
        'completedAt': challenge['completedAt'],
      },
    };
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  Future<void> _logout(AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (!mounted) return;
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GamifiedEntryScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _pickAndUploadProfilePicture(AuthProvider authProvider) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take Photo'),
                  onTap: () => Navigator.pop(context, 'camera'),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from Gallery'),
                  onTap: () => Navigator.pop(context, 'gallery'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    setState(() => _isUploadingProfilePicture = true);

    try {
      String? base64Data;

      if (source == 'camera') {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
        );
        if (pickedFile == null) {
          setState(() => _isUploadingProfilePicture = false);
          return;
        }
        final originalBytes = await pickedFile.readAsBytes();
        final compressed = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: 400,
          minHeight: 400,
          quality: 75,
          format: CompressFormat.jpeg,
        ).catchError((_) => originalBytes);
        base64Data = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      } else {
        final galleryData = await pickGalleryImage();
        if (galleryData == null) {
          setState(() => _isUploadingProfilePicture = false);
          return;
        }
        final base64Str = galleryData.replaceFirst(
          RegExp(r'^data:image/\w+;base64,'),
          '',
        );
        final originalBytes = base64Decode(base64Str);
        final compressed = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: 400,
          minHeight: 400,
          quality: 75,
          format: CompressFormat.jpeg,
        ).catchError((_) => originalBytes);
        base64Data = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      }

      final authService = AuthService();
      final updatedUrl = await authService.uploadProfilePicture(
        imageData: base64Data,
        token: authProvider.token,
      );

      await authProvider.setLocalAvatarPath(updatedUrl);

      if (!mounted) return;
      setState(() => _isUploadingProfilePicture = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingProfilePicture = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update picture: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final avatarPath = authProvider.avatarPath;
    final userRole =
        normalizeRole(
          authProvider.userData?['role'] as String? ?? authProvider.userRole,
        ) ??
        'member';
    final isMember = isMemberRole(userRole);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: EditorialBackdrop(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EditorialKicker('Profile'),
                  const SizedBox(height: 18),
                  _buildHeroCard(context, authProvider, avatarPath, userRole),
                  const SizedBox(height: 18),
                  _buildAccountCard(context, authProvider, userRole),
                  if (isMember) ...[
                    const SizedBox(height: 18),
                    _buildMemberDetailsArea(context),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: EditorialSecondaryButton(
                      label: 'Logout',
                      onPressed: _isSaving ? null : () => _logout(authProvider),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConfettiSuccess(show: _showConfetti),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    AuthProvider authProvider,
    String? avatarPath,
    String userRole,
  ) {
    final theme = Theme.of(context);
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: GestureDetector(
              onTap: _isUploadingProfilePicture
                  ? null
                  : () => _pickAndUploadProfilePicture(authProvider),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 116,
                    height: 116,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                      ),
                      child: avatarPath != null
                          ? ClipOval(child: _buildAvatarImage(avatarPath, 108))
                          : Icon(
                              Icons.person_outline_rounded,
                              size: 54,
                              color: theme.colorScheme.primary,
                            ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingProfilePicture
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF390C00),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Color(0xFF390C00),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              authProvider.userName ?? 'GymMate Member',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              isMemberRole(userRole)
                  ? 'Keep your member details, preferences, and goals ready in one clean space.'
                  : 'Keep your account details current so your gym and workspace stay in sync.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _formatRole(userRole).toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Role avatar', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _avatarOptionsForRole(userRole).map((option) {
              final selected = avatarPath == option.$2;
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSavingAvatar ? null : () => _chooseRoleAvatar(authProvider, option.$2),
                child: Container(
                  width: 92,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(child: _buildAvatarImage(option.$2, 54)),
                      const SizedBox(height: 8),
                      Text(option.$1, style: theme.textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    AuthProvider authProvider,
    String userRole,
  ) {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialSectionHeading(
            eyebrow: 'Account Details',
            title: 'Your account details.',
            subtitle: 'Update your name or email here.',
          ),
          const SizedBox(height: 22),
          _ProfileField(
            label: 'Full Name',
            controller: _nameController,
            enabled: !_isSaving,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),
          _ProfileField(
            label: 'Email',
            controller: _emailController,
            enabled: !_isSaving,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _LockedProfileField(label: 'Role', value: _formatRole(userRole)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: EditorialPrimaryButton(
              label: 'Save account',
              loading: _isSaving,
              onPressed: _saveProfile,
              affordance: EditorialPrimaryAffordance.arrow,
            ),
          ),
          const SizedBox(height: 24),
          EditorialSectionHeading(
            eyebrow: authProvider.userData?['hasPassword'] == true ? 'Password' : 'Set Password',
            title: authProvider.userData?['hasPassword'] == true
                ? 'Change your password.'
                : 'Create your password.',
            subtitle: authProvider.userData?['hasPassword'] == true
                ? 'Use your current password before saving a new one.'
                : 'First-time invite access can set a password from here.',
          ),
          const SizedBox(height: 18),
          if (authProvider.userData?['hasPassword'] == true) ...[
            _ProfileField(
              label: 'Current Password',
              controller: _currentPasswordController,
              enabled: !_isSavingPassword,
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
            ),
            const SizedBox(height: 16),
          ],
          _ProfileField(
            label: 'New Password',
            controller: _newPasswordController,
            enabled: !_isSavingPassword,
            keyboardType: TextInputType.visiblePassword,
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _ProfileField(
            label: 'Confirm New Password',
            controller: _confirmPasswordController,
            enabled: !_isSavingPassword,
            keyboardType: TextInputType.visiblePassword,
            obscureText: true,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: EditorialSecondaryButton(
              label: authProvider.userData?['hasPassword'] == true
                  ? 'Change password'
                  : 'Set password',
              onPressed: _isSavingPassword
                  ? null
                  : () => _savePassword(authProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberDetailsArea(BuildContext context) {
    if (_memberDetailsLoading) {
      return const EditorialSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialSectionHeading(
              eyebrow: 'Member Details',
              title: 'Loading your training profile.',
              subtitle:
                  'Pulling in your goals, preferences, and challenge data.',
            ),
            SizedBox(height: 24),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_memberDetailsError != null) {
      return EditorialSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditorialSectionHeading(
              eyebrow: 'Member Details',
              title: 'We could not load your profile details.',
              subtitle:
                  'Try again to bring your goals and preferences back in view.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: EditorialPrimaryButton(
                label: 'Try Again',
                onPressed: _loadMemberDetails,
                affordance: EditorialPrimaryAffordance.arrow,
              ),
            ),
          ],
        ),
      );
    }

    if (_savedMemberData == null || _draftMemberData == null) {
      return EditorialSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditorialSectionHeading(
              eyebrow: 'Member Details',
              title: 'Your training profile is ready to be filled in.',
              subtitle:
                  'As soon as your member details are available, they will live here.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: EditorialPrimaryButton(
                label: 'Reload Details',
                onPressed: _loadMemberDetails,
                affordance: EditorialPrimaryAffordance.arrow,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildProfileSnapshotCard(context),
        const SizedBox(height: 18),
        _buildFitnessGoalsCard(context),
        const SizedBox(height: 18),
        _buildDietCard(context),
        const SizedBox(height: 18),
        _buildWorkoutCard(context),
        const SizedBox(height: 18),
        _buildChallengeCard(context),
      ],
    );
  }

  Widget _buildProfileSnapshotCard(BuildContext context) {
    final draft = _draftMemberData!;
    final profile = Map<String, dynamic>.from(draft['profile'] ?? {});
    final isEditing = _editingSection == 'profile';

    return _MemberSectionCard(
      eyebrow: 'Profile Snapshot',
      title: 'The physical details that shape your plan.',
      subtitle:
          'Keep this current so training and nutrition stay calibrated to you.',
      isEditing: isEditing,
      isSaving: _savingSection == 'profile',
      onEdit: () => _beginEdit('profile'),
      onCancel: _cancelEdit,
      onSave: () => _saveMemberSection('profile'),
      child: isEditing
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Age',
                        controller: _ageController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InlineDropdownField(
                        label: 'Gender',
                        value: (profile['gender'] as String?) ?? 'male',
                        items: _genderOptions,
                        onChanged: (value) {
                          setState(() {
                            final next = Map<String, dynamic>.from(
                              draft['profile'] ?? {},
                            );
                            next['gender'] = value;
                            draft['profile'] = next;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Weight (kg)',
                        controller: _weightController,
                        enabled: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Height (cm)',
                        controller: _heightController,
                        enabled: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              children: [
                _InfoRow(label: 'Age', value: _displayNumber(profile['age'])),
                _InfoRow(
                  label: 'Gender',
                  value: _friendlyValue(profile['gender']),
                ),
                _InfoRow(
                  label: 'Weight',
                  value: _displayMeasurement(profile['weight'], 'kg'),
                ),
                _InfoRow(
                  label: 'Height',
                  value: _displayMeasurement(profile['height'], 'cm'),
                  isLast: true,
                ),
              ],
            ),
    );
  }

  Widget _buildFitnessGoalsCard(BuildContext context) {
    final draft = _draftMemberData!;
    final goals = List<String>.from(draft['fitnessGoals'] ?? const <String>[]);
    final isEditing = _editingSection == 'goals';

    return _MemberSectionCard(
      eyebrow: 'Fitness Goals',
      title: 'The outcomes your training should keep chasing.',
      subtitle: 'Choose the goals you want GymMate to keep front and center.',
      isEditing: isEditing,
      isSaving: _savingSection == 'goals',
      onEdit: () => _beginEdit('goals'),
      onCancel: _cancelEdit,
      onSave: () => _saveMemberSection('goals'),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _goalOptions.map((goal) {
          final selected = goals.contains(goal.$2);
          return FilterChip(
            label: Text(goal.$1),
            selected: selected,
            onSelected: isEditing
                ? (value) {
                    setState(() {
                      final next = List<String>.from(goals);
                      if (value) {
                        next.add(goal.$2);
                      } else {
                        next.remove(goal.$2);
                      }
                      draft['fitnessGoals'] = next.toSet().toList();
                    });
                  }
                : null,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDietCard(BuildContext context) {
    final draft = _draftMemberData!;
    final prefs = Map<String, dynamic>.from(draft['dietPreferences'] ?? {});
    final isEditing = _editingSection == 'diet';

    return _MemberSectionCard(
      eyebrow: 'Diet Preferences',
      title: 'How your meals should fit your actual week.',
      subtitle:
          'Keep your food style and day-to-day preferences easy to update.',
      isEditing: isEditing,
      isSaving: _savingSection == 'diet',
      onEdit: () => _beginEdit('diet'),
      onCancel: _cancelEdit,
      onSave: () => _saveMemberSection('diet'),
      child: isEditing
          ? Column(
              children: [
                _InlineDropdownField(
                  label: 'Diet Type',
                  value: (prefs['type'] as String?) ?? 'flexible',
                  items: _dietTypes,
                  onChanged: (value) {
                    setState(() {
                      final next = Map<String, dynamic>.from(
                        draft['dietPreferences'] ?? {},
                      );
                      next['type'] = value;
                      draft['dietPreferences'] = next;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Daily Meals',
                        controller: _dailyMealsController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Water Intake',
                        controller: _waterIntakeController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ProfileField(
                  label: 'Allergies (comma separated)',
                  controller: _allergiesController,
                  enabled: true,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 16),
                _ProfileField(
                  label: 'Restrictions (comma separated)',
                  controller: _restrictionsController,
                  enabled: true,
                  keyboardType: TextInputType.text,
                ),
              ],
            )
          : Column(
              children: [
                _InfoRow(
                  label: 'Diet Type',
                  value: _friendlyValue(prefs['type']),
                ),
                _InfoRow(
                  label: 'Daily Meals',
                  value: _displayNumber(prefs['dailyMeals']),
                ),
                _InfoRow(
                  label: 'Water Intake',
                  value: '${_displayNumber(prefs['waterIntake'])} glasses',
                ),
                _InfoRow(
                  label: 'Allergies',
                  value: _friendlyList(prefs['allergies']),
                ),
                _InfoRow(
                  label: 'Restrictions',
                  value: _friendlyList(prefs['restrictions']),
                  isLast: true,
                ),
              ],
            ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context) {
    final draft = _draftMemberData!;
    final habits = Map<String, dynamic>.from(draft['workoutHabits'] ?? {});
    final favoriteExercises = List<String>.from(
      habits['favoriteExercises'] ?? const <String>[],
    );
    final isEditing = _editingSection == 'workout';

    return _MemberSectionCard(
      eyebrow: 'Workout Preferences',
      title: 'The rhythm and training styles that fit your schedule.',
      subtitle: 'Keep your time, pace, and favorite training styles current.',
      isEditing: isEditing,
      isSaving: _savingSection == 'workout',
      onEdit: () => _beginEdit('workout'),
      onCancel: _cancelEdit,
      onSave: () => _saveMemberSection('workout'),
      child: isEditing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InlineDropdownField(
                  label: 'Preferred Time',
                  value: (habits['preferredTime'] as String?) ?? 'flexible',
                  items: _preferredTimes,
                  onChanged: (value) {
                    setState(() {
                      final next = Map<String, dynamic>.from(
                        draft['workoutHabits'] ?? {},
                      );
                      next['preferredTime'] = value;
                      draft['workoutHabits'] = next;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _InlineDropdownField(
                  label: 'Activity Level',
                  value:
                      (habits['currentActivityLevel'] as String?) ??
                      'moderately_active',
                  items: _activityLevels,
                  onChanged: (value) {
                    setState(() {
                      final next = Map<String, dynamic>.from(
                        draft['workoutHabits'] ?? {},
                      );
                      next['currentActivityLevel'] = value;
                      draft['workoutHabits'] = next;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileField(
                        label: 'Workouts Per Week',
                        controller: _workoutsPerWeekController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ProfileField(
                        label: 'Session Duration (min)',
                        controller: _sessionDurationController,
                        enabled: true,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Favorite Exercises',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _exerciseTypes.map((exercise) {
                    final selected = favoriteExercises.contains(exercise.$2);
                    return FilterChip(
                      label: Text(exercise.$1),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          final next = List<String>.from(favoriteExercises);
                          if (value) {
                            next.add(exercise.$2);
                          } else {
                            next.remove(exercise.$2);
                          }
                          final habitsNext = Map<String, dynamic>.from(
                            draft['workoutHabits'] ?? {},
                          );
                          habitsNext['favoriteExercises'] = next
                              .toSet()
                              .toList();
                          draft['workoutHabits'] = habitsNext;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  value: habits['hasInjuries'] == true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Working around injuries'),
                  subtitle: const Text(
                    'Turn this on if your plan should account for injury limits.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      final next = Map<String, dynamic>.from(
                        draft['workoutHabits'] ?? {},
                      );
                      next['hasInjuries'] = value;
                      if (!value) {
                        next['injuryDetails'] = null;
                        _injuryDetailsController.clear();
                      }
                      draft['workoutHabits'] = next;
                    });
                  },
                ),
                if (habits['hasInjuries'] == true) ...[
                  const SizedBox(height: 8),
                  _ProfileField(
                    label: 'Injury Details',
                    controller: _injuryDetailsController,
                    enabled: true,
                    keyboardType: TextInputType.text,
                  ),
                ],
              ],
            )
          : Column(
              children: [
                _InfoRow(
                  label: 'Preferred Time',
                  value: _friendlyValue(habits['preferredTime']),
                ),
                _InfoRow(
                  label: 'Activity Level',
                  value: _friendlyValue(habits['currentActivityLevel']),
                ),
                _InfoRow(
                  label: 'Workouts Per Week',
                  value: _displayNumber(habits['workoutsPerWeek']),
                ),
                _InfoRow(
                  label: 'Session Duration',
                  value: '${_displayNumber(habits['sessionDuration'])} minutes',
                ),
                _InfoRow(
                  label: 'Favorite Exercises',
                  value: _friendlyList(habits['favoriteExercises']),
                ),
                _InfoRow(
                  label: 'Injury Support',
                  value: habits['hasInjuries'] == true
                      ? (_stringOrDash(habits['injuryDetails']))
                      : 'No injury limits noted',
                  isLast: true,
                ),
              ],
            ),
    );
  }

  Widget _buildChallengeCard(BuildContext context) {
    final draft = _draftMemberData!;
    final challenge = Map<String, dynamic>.from(draft['firstChallenge'] ?? {});
    final locked =
        challenge['isAccepted'] == true || challenge['isCompleted'] == true;
    final isEditing = _editingSection == 'challenge';
    final challengeType = (challenge['type'] as String?) ?? '7_day_checkin';

    return _MemberSectionCard(
      eyebrow: 'Challenge',
      title: 'Your challenge.',
      subtitle: locked
          ? 'Progress stays read-only once it begins.'
          : 'You can change this before it begins.',
      isEditing: isEditing,
      isSaving: _savingSection == 'challenge',
      canEdit: !locked,
      onEdit: locked ? null : () => _beginEdit('challenge'),
      onCancel: _cancelEdit,
      onSave: () => _saveMemberSection('challenge'),
      child: isEditing
          ? Column(
              children: [
                _InlineDropdownField(
                  label: 'Challenge Type',
                  value: challengeType,
                  items: _challengeTypes,
                  onChanged: (value) {
                    setState(() {
                      final next = Map<String, dynamic>.from(
                        draft['firstChallenge'] ?? {},
                      );
                      next['type'] = value;
                      draft['firstChallenge'] = next;
                    });
                  },
                ),
                const SizedBox(height: 16),
                _ChallengeStatusBlock(challenge: challenge),
              ],
            )
          : _ChallengeStatusBlock(challenge: challenge),
    );
  }

  String _numberOrBlank(dynamic value) {
    if (value == null) return '';
    if (value is int) return value == 0 ? '' : value.toString();
    if (value is double)
      return value == 0
          ? ''
          : value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    final text = value.toString();
    return text == '0' || text == '0.0' ? '' : text;
  }

  String _displayNumber(dynamic value) {
    if (value == null) return '-';
    if (value is num && value <= 0) return '-';
    return value.toString();
  }

  String _displayMeasurement(dynamic value, String unit) {
    final number = _displayNumber(value);
    return number == '-' ? '-' : '$number $unit';
  }

  String _joinCsv(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).join(', ');
    }
    return '';
  }

  List<String> _splitCsv(String raw) {
    return raw
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _friendlyValue(dynamic value) {
    if (value == null) return '-';
    final match = value.toString();
    if (match.isEmpty) return '-';
    return match
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _friendlyList(dynamic value) {
    if (value is! List || value.isEmpty) return 'None';
    return value.map((item) => _friendlyValue(item)).join(', ');
  }

  String _stringOrDash(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '-' : text;
  }
}

class _MemberSectionCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final bool isEditing;
  final bool isSaving;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  const _MemberSectionCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isEditing,
    required this.isSaving,
    this.canEdit = true,
    this.onEdit,
    this.onCancel,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSectionHeading(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            trailing: canEdit
                ? _SectionActionButton(
                    icon: isEditing ? Icons.close_rounded : Icons.edit_rounded,
                    onPressed: isEditing ? onCancel : onEdit,
                    tooltip: isEditing ? 'Cancel' : 'Edit',
                  )
                : null,
          ),
          const SizedBox(height: 20),
          child,
          if (isEditing) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: EditorialSecondaryButton(
                    label: 'Cancel',
                    onPressed: isSaving ? null : onCancel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EditorialPrimaryButton(
                    label: 'Save',
                    loading: isSaving,
                    onPressed: onSave,
                    affordance: EditorialPrimaryAffordance.arrow,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  const _SectionActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.54,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

class _ChallengeStatusBlock extends StatelessWidget {
  final Map<String, dynamic> challenge;

  const _ChallengeStatusBlock({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final status =
        (challenge['statusLabel'] ??
                (challenge['isCompleted'] == true
                    ? 'Completed'
                    : challenge['isAccepted'] == true
                    ? 'In Progress'
                    : 'Ready'))
            .toString();
    final progress = '${challenge['progress'] ?? 0}%';
    final startDate = challenge['startDate'] == null
        ? 'Not started'
        : challenge['startDate'].toString().split('T').first;
    final summary = (challenge['summary'] ?? '').toString();
    final nextStep = (challenge['nextStep'] ?? '').toString();
    final current = challenge['current'];
    final target = challenge['target'];

    return Column(
      children: [
        _InfoRow(label: 'Type', value: _friendlyLabel(challenge['type'])),
        _InfoRow(label: 'Status', value: status),
        if (summary.isNotEmpty) _InfoRow(label: 'Summary', value: summary),
        if (current != null && target != null)
          _InfoRow(label: 'Progress', value: '$current / $target'),
        _InfoRow(label: 'Progress', value: progress),
        if (nextStep.isNotEmpty) _InfoRow(label: 'Next Step', value: nextStep),
        _InfoRow(label: 'Start Date', value: startDate, isLast: true),
      ],
    );
  }

  String _friendlyLabel(dynamic value) {
    final text = (value ?? '').toString();
    if (text.isEmpty) return '-';
    return text
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}

String _friendlyMemberDetailsError(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('403') ||
      normalized.contains('expired token') ||
      normalized.contains('session')) {
    return 'Your session expired. Please log in again.';
  }
  return 'We could not load your profile details right now.';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.14),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  const _InlineDropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: items.any((item) => item.$2 == value) ? value : items.first.$2,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.56,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item.$2,
                  child: Text(item.$1),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;
  final bool obscureText;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.keyboardType,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.56,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _LockedProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.56,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
              Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
