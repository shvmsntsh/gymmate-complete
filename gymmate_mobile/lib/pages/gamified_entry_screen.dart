import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/animated_background.dart';
import '../widgets/role_card.dart';
import '../widgets/progress_bar.dart';
import '../widgets/animated_form_field.dart';
import '../widgets/confetti_success.dart';
import '../providers/auth_provider.dart';
import '../widgets/animated_entry_options.dart';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:gymmate_mobile/themes/app_colors.dart';
import '../main.dart';
import 'quick_join_screen.dart';
import '../widgets/entry_carousel.dart';

// Entry states
enum EntryState { entry, login, chooseRole, register, quickJoin }

class GamifiedEntryScreen extends StatefulWidget {
  const GamifiedEntryScreen({Key? key}) : super(key: key);

  @override
  State<GamifiedEntryScreen> createState() => _GamifiedEntryScreenState();
}

class _GamifiedEntryScreenState extends State<GamifiedEntryScreen> {
  EntryState _state = EntryState.entry;
  String? _selectedRole;
  bool _showConfetti = false;
  double _progress = 0.0;
  String? _registerError;
  String? _loginError;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginLoading = false;

  // Registration controllers
  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();
  final _regCodeController = TextEditingController();
  final _regGymNameController = TextEditingController();
  final _regPhoneNumberController = TextEditingController();
  bool _regLoading = false;

  // Registration state
  String? _backendRole;
  String? _backendGymId;
  bool _isSuperadmin = false;
  bool? _inviteCodeValid; // null = untouched, true = valid, false = invalid

  void _showLogin() => setState(() => _state = EntryState.login);
  void _showJoin() => setState(() => _state = EntryState.chooseRole);
  void _showQuickJoin() => setState(() => _state = EntryState.quickJoin);
  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _state = EntryState.register;
      _progress = 0.5;
      _registerError = null;
    });
  }
  void _backToEntry() => setState(() => _state = EntryState.entry);
  void _backToRole() {
    // Clear all registration fields when going back from sign up
    _regNameController.clear();
    _regEmailController.clear();
    _regPasswordController.clear();
    _regConfirmController.clear();
    _regCodeController.clear();
    _regGymNameController.clear();
    setState(() => _state = EntryState.chooseRole);
  }

  Future<void> _onLogin() async {
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.login(
        _loginEmailController.text.trim(),
        _loginPasswordController.text.trim(),
      );
      // On success, navigation is handled by main.dart's Consumer
    } catch (e) {
      setState(() => _loginError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loginLoading = false);
    }
  }

  Future<void> _verifyInviteCode(String code) async {
    setState(() => _registerError = null);
    debugPrint('[DEBUG] _verifyInviteCode raw code: $code');
    code = code.trim().toUpperCase();
    debugPrint('[DEBUG] _verifyInviteCode normalized code: $code');
    // Handle empty code case - reset state but don't show error
    if (code.isEmpty) {
      debugPrint('[DEBUG] _verifyInviteCode: code is empty, resetting state');
      setState(() {
        _isSuperadmin = false;
        _backendRole = null;
        _inviteCodeValid = null;
        if (_regGymNameController.text == 'GymMate HQ' && _selectedRole?.toLowerCase() != 'owner') {
          _regGymNameController.clear();
        }
      });
      return;
    }
    // Check for superadmin code
    if (code == '123456') {
      debugPrint('[DEBUG] _verifyInviteCode: superadmin code detected');
      setState(() {
        _isSuperadmin = true;
        _backendRole = 'superadmin';
        _inviteCodeValid = true;
        _regGymNameController.text = 'GymMate HQ';
        _registerError = null;
      });
      return;
    }
    // Reset superadmin flag if code changes
    if (_isSuperadmin) {
      debugPrint('[DEBUG] _verifyInviteCode: code changed, clearing superadmin state');
      setState(() {
        _isSuperadmin = false;
        _backendRole = null;
        _inviteCodeValid = null;
        _regGymNameController.clear();
      });
    }
    // Only call backend for non-superadmin
    try {
      setState(() => _regLoading = true);
      debugPrint('[DEBUG] _verifyInviteCode: calling backend with code: $code');
      final url = Uri.parse('${ApiConfig.baseUrl}/api/invite/validate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code})
      );
      debugPrint('[DEBUG] _verifyInviteCode: backend response status: ${response.statusCode}');
      debugPrint('[DEBUG] _verifyInviteCode: backend response body: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[DEBUG] _verifyInviteCode: backend data: $data');
        // Role mapping check
        String expectedRole = '';
        if (_selectedRole != null) {
          final sel = _selectedRole!.toLowerCase();
          if (sel == 'owner') expectedRole = 'gym_owner';
          else if (sel == 'trainer') expectedRole = 'gym_trainer';
          else if (sel == 'member') expectedRole = 'gym_member';
        }
        if (expectedRole.isNotEmpty && data['role'] != expectedRole) {
          setState(() {
            _backendRole = null;
            _backendGymId = null;
            _inviteCodeValid = false;
            _registerError = 'This invite code is not valid for the selected role.';
          });
          debugPrint('[DEBUG] _verifyInviteCode: code role mismatch: backend=${data['role']} expected=$expectedRole');
          return;
        }
        setState(() {
          _backendRole = data['role'];
          _backendGymId = data['gymId'];
          _inviteCodeValid = true;
          _registerError = null;
        });
      } else {
        setState(() {
          _backendRole = null;
          _backendGymId = null;
          _inviteCodeValid = false;
          _registerError = 'Invalid or already used invite code.';
        });
        debugPrint('[DEBUG] _verifyInviteCode: error set: $_registerError');
      }
    } catch (e) {
      setState(() {
        _backendRole = null;
        _backendGymId = null;
        _inviteCodeValid = false;
        _registerError = 'Failed to verify invite code.';
      });
      debugPrint('[DEBUG] _verifyInviteCode: exception: $e');
    } finally {
      setState(() => _regLoading = false);
      debugPrint('[DEBUG] _verifyInviteCode: loading set to false');
    }
  }

  Future<void> _onRegister() async {
    setState(() => _registerError = null);
    final errors = <String>[];
    final name = _regNameController.text.trim();
    final email = _regEmailController.text.trim();
    final password = _regPasswordController.text;
    final confirm = _regConfirmController.text;
    final code = _regCodeController.text.trim().toUpperCase();
    final gymName = _regGymNameController.text.trim();
    final phoneNumber = _regPhoneNumberController.text.trim();
    final role = _selectedRole?.toLowerCase() ?? '';
    debugPrint('[DEBUG] _onRegister fields: name=$name, email=$email, password=$password, confirm=$confirm, code=$code, gymName=$gymName, role=$role, backendRole=$_backendRole, isSuperadmin=$_isSuperadmin');
    // Validate fields
    if (name.isEmpty) errors.add('Name is required');
    if (email.isEmpty) errors.add('Email is required');
    else if (!RegExp(r"^\S+@\S+\.\S+").hasMatch(email)) errors.add('Invalid email format');
    if (password.isEmpty) errors.add('Password is required');
    else if (password.length < 6) errors.add('Password must be at least 6 characters');
    if (confirm.isEmpty) errors.add('Confirm password is required');
    else if (password != confirm) errors.add('Passwords do not match');
    if (code.isEmpty) errors.add('Invite code is required');
    if ((role == 'owner' || _isSuperadmin || _backendRole == 'gym_owner') && gymName.isEmpty) errors.add('Gym name is required');
    if (errors.isNotEmpty) {
      debugPrint('[DEBUG] _onRegister validation errors: $errors');
      setState(() => _registerError = errors.join(', '));
      return;
    }
    // Always verify invite code if not superadmin and code changed or not verified
    if (!_isSuperadmin && (_backendRole == null || code != _regCodeController.text.trim().toUpperCase())) {
      setState(() => _regLoading = true);
      debugPrint('[DEBUG] _onRegister: verifying invite code: $code');
      await _verifyInviteCode(code);
      setState(() => _regLoading = false);
      if (_registerError != null || (_backendRole == null && !_isSuperadmin)) {
        debugPrint('[DEBUG] _onRegister: invite code verification failed, error: $_registerError');
        return;
      }
    }
    setState(() { _regLoading = true; _registerError = null; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'phone_number': phoneNumber,
      };
      if (_isSuperadmin) {
        data['role'] = 'superadmin';
        data['gymName'] = gymName;
        data['inviteCode'] = code;
      } else if (_backendRole == 'gym_owner') {
        data['role'] = 'gym_owner';
        data['inviteCode'] = code;
        data['gymName'] = gymName;
      } else if (_backendRole == 'gym_trainer' || _backendRole == 'gym_member') {
        data['role'] = _backendRole;
        data['inviteCode'] = code;
        if (_backendGymId != null) data['gymId'] = _backendGymId;
      } else {
        data['role'] = role == 'owner' ? 'gym_owner' : role == 'trainer' ? 'gym_trainer' : 'gym_member';
        data['inviteCode'] = code;
      }
      debugPrint('[DEBUG] _onRegister: registration payload: $data');
      final success = await authProvider.register(data);
      debugPrint('[DEBUG] _onRegister: registration result: $success');
      if (success) {
        setState(() { _showConfetti = true; _progress = 1.0; });
        await Future.delayed(const Duration(milliseconds: 1800));
        setState(() => _showConfetti = false);
      } else {
        setState(() => _registerError = 'Registration failed.');
        debugPrint('[DEBUG] _onRegister: registration failed');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[DEBUG] _onRegister: exception: $msg');
      // Handle known backend errors
      if (msg.contains('Superadmin already exists')) {
        setState(() => _registerError = 'Superadmin already exists.');
      } else if (msg.contains('already used invitation code') || msg.contains('Invalid or already used invite code')) {
        setState(() => _registerError = 'Invalid or already used invite code.');
      } else if (msg.contains('An account with this email already exists')) {
        setState(() => _registerError = 'An account with this email already exists.');
      } else {
        setState(() => _registerError = msg);
      }
    } finally {
      setState(() => _regLoading = false);
      debugPrint('[DEBUG] _onRegister: loading set to false');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuth) {
          // Redirect to dashboard if already authenticated
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => MainNavigationScaffold(key: MainNavigationScaffold.navKey)),
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final theme = Theme.of(context);
        return Scaffold(
          body: Stack(
            children: [
              const AnimatedBackground(),
              SafeArea(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _state == EntryState.entry
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Spacer(),
                              // Top illustration restored and centered
                              Image.asset(
                                'assets/illustration.png',
                                height: 160,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Welcome to GymMate',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
                              const SizedBox(height: 32),
                              EntryCarousel(
                                onLogin: _showLogin,
                                onJoin: _showJoin,
                                onQuickJoin: _showQuickJoin,
                              ),
                              const Spacer(),
                            ],
                          )
                        : _state == EntryState.login
                            ? _AnimatedLoginForm(
                                emailController: _loginEmailController,
                                passwordController: _loginPasswordController,
                                loading: _loginLoading,
                                error: _loginError,
                                onLogin: _onLogin,
                                onBack: _backToEntry,
                              )
                            : _state == EntryState.chooseRole
                                ? _AnimatedRoleSelection(
                                    selectedRole: _selectedRole,
                                    onSelect: _selectRole,
                                    onBack: _backToEntry,
                                  )
                                : _state == EntryState.quickJoin
                                    ? QuickJoinScreen(onBack: _backToEntry)
                                    : _selectedRole != null
                                        ? _UnifiedRoleRegistration(
                                            role: _selectedRole!,
                                            nameController: _regNameController,
                                            emailController: _regEmailController,
                                            passwordController: _regPasswordController,
                                            confirmController: _regConfirmController,
                                            codeController: _regCodeController,
                                            gymNameController: _regGymNameController,
                                            phoneNumberController: _regPhoneNumberController,
                                            loading: _regLoading,
                                            progress: _progress,
                                            showConfetti: _showConfetti,
                                            error: _registerError,
                                            onRegister: _onRegister,
                                            onBack: _backToRole,
                                            onCodeChanged: _verifyInviteCode,
                                            isSuperadmin: _isSuperadmin,
                                            backendRole: _backendRole,
                                            inviteCodeValid: _inviteCodeValid,
                                          )
                                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedLoginForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  const _AnimatedLoginForm({
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onLogin,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
            const SizedBox(height: 8),
            Text('Login', style: theme.textTheme.titleLarge),
            if (error != null) ...[              const SizedBox(height: 8),
              Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            AnimatedFormField(
              controller: emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final regex = RegExp(r"^\S+@\S+\.\S+$");
                return regex.hasMatch(v) ? null : 'Invalid';
              },
              index: 0,
            ),
            const SizedBox(height: 16),
            AnimatedFormField(
              controller: passwordController,
              hintText: 'Password',
              isPassword: true,
              validator: (v){
                if(v==null||v.isEmpty) return 'Required';
                return v.length>=6?null:'Min 6 chars';
              },
              index:1,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 24),
            loading
                ? const CircularProgressIndicator()
                : GestureDetector(
                    onTap: onLogin,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.accentYellow,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentYellow.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Login',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textOnAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ).animate().shimmer(duration: 800.ms),
                      ),
                    ).animate().scaleXY(begin: 0.98, end: 1.0, duration: 200.ms, curve: Curves.easeOut),
                  ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
      ),
    );
  }
}

class _AnimatedRoleSelection extends StatelessWidget {
  final String? selectedRole;
  final void Function(String) onSelect;
  final VoidCallback onBack;
  const _AnimatedRoleSelection({
    required this.selectedRole,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final roles = [
      {'title': 'Owner'},
      {'title': 'Trainer'},
      {'title': 'Member'},
    ];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        const SizedBox(height: 8),
        Text('Choose Your Role', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(roles.length, (i) {
            final r = roles[i];
            return RoleCard(
              title: r['title']!,
              selected: selectedRole == r['title'],
              onTap: () => onSelect(r['title']!),
              index: i,
            );
          }),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms);
  }
}

class _UnifiedRoleRegistration extends StatefulWidget {
  final String role;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final TextEditingController codeController;
  final TextEditingController gymNameController;
  final TextEditingController phoneNumberController;
  final bool loading;
  final double progress;
  final bool showConfetti;
  final String? error;
  final VoidCallback onRegister;
  final VoidCallback onBack;
  final Function(String) onCodeChanged;
  final bool isSuperadmin;
  final String? backendRole;
  final bool? inviteCodeValid;

  const _UnifiedRoleRegistration({
    required this.role,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.codeController,
    required this.gymNameController,
    required this.phoneNumberController,
    required this.loading,
    required this.progress,
    required this.showConfetti,
    required this.error,
    required this.onRegister,
    required this.onBack,
    required this.onCodeChanged,
    required this.isSuperadmin,
    required this.backendRole,
    required this.inviteCodeValid,
  });

  @override
  State<_UnifiedRoleRegistration> createState() => _UnifiedRoleRegistrationState();
}

class _UnifiedRoleRegistrationState extends State<_UnifiedRoleRegistration> {
  // Track if we're currently verifying a code to prevent duplicate requests
  bool _isVerifyingCode = false;
  // Store the last verified code to prevent unnecessary verification
  String _lastVerifiedCode = '';

  @override
  void initState() {
    super.initState();
    widget.codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    widget.codeController.removeListener(_onCodeChanged);
    super.dispose();
  }

  void _onCodeChanged() {
    if (_isVerifyingCode) return; // Prevent multiple simultaneous verifications
    
    final code = widget.codeController.text.trim();
    
    // Don't verify if it's the same code we already verified
    if (code == _lastVerifiedCode && code.isNotEmpty) return;
    
    // Debounce code validation to avoid excessive API calls
    _isVerifyingCode = true;
    Future.delayed(const Duration(milliseconds: 500), () {
      // Only verify if the code is still the same after the delay
      if (widget.codeController.text.trim() == code) {
        _lastVerifiedCode = code;
        widget.onCodeChanged(code);
      }
      _isVerifyingCode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine image, title, and code label based on role
    String imageAsset;
    String title;
    String codeLabel;
    String heroTag;
    bool showGymName = false;
    final role = widget.role.toLowerCase();
    
    if (widget.isSuperadmin) {
      imageAsset = 'assets/images/owner_illustration.png';
      title = 'Sign Up as Superadmin';
      codeLabel = 'Superadmin Code';
      heroTag = 'role-illustration-Owner';
      showGymName = true;
    } else if (role == 'owner') {
      imageAsset = 'assets/images/owner_illustration.png';
      title = 'Sign Up as Owner';
      codeLabel = 'Invite Code';
      heroTag = 'role-illustration-Owner';
      showGymName = true;
    } else if (role == 'trainer') {
      imageAsset = 'assets/images/trainer_illustration.png';
      title = 'Sign Up as Trainer';
      codeLabel = 'Gym Code';
      heroTag = 'role-illustration-Trainer';
      showGymName = false;
    } else if (role == 'member') {
      imageAsset = 'assets/images/member_illustration.png';
      title = 'Sign Up as Member';
      codeLabel = 'Gym Code';
      heroTag = 'role-illustration-Member';
      showGymName = false;
    } else {
      imageAsset = 'assets/images/owner_illustration.png';
      title = 'Sign Up';
      codeLabel = 'Invite Code';
      heroTag = 'role-illustration-Owner';
      showGymName = false;
    }
    
    // Show gym name field for owner or if backend role is gym_owner
    if (widget.backendRole == 'gym_owner') {
      showGymName = true;
    }
    
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBack,
                ),
                Hero(
                  tag: heroTag,
                  child: Image.asset(
                    imageAsset,
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title, style: theme.textTheme.titleLarge),
                AnimatedProgressBar(progress: widget.progress),
                if (widget.error != null) ...[                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(widget.error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red)),
                  ),
                ],
                const SizedBox(height: 16),
                AnimatedFormField(
                  controller: widget.codeController,
                  hintText: codeLabel,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  index: 0,
                  isValid: widget.inviteCodeValid,
                ),
                const SizedBox(height: 16),
                AnimatedFormField(
                  controller: widget.nameController,
                  hintText: 'Full Name',
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  index: 1,
                ),
                const SizedBox(height: 16),
                AnimatedFormField(
                  controller: widget.phoneNumberController,
                  hintText: 'Phone Number (Optional)',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    if (!RegExp(r'^(?:\+91)?[6-9]\d{9}$').hasMatch(v)) {
                      return 'Invalid phone number';
                    }
                    return null;
                  },
                  index: 2,
                ),
                const SizedBox(height: 16),
                if (showGymName) ...[                  AnimatedFormField(
                    controller: widget.gymNameController,
                    hintText: 'Gym Name',
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    enabled: !widget.isSuperadmin,
                    index: 3,
                  ),
                  const SizedBox(height: 16),
                ],
                AnimatedFormField(
                  controller: widget.emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    final regex = RegExp(r"^\S+@\S+\.\S+$");
                    return regex.hasMatch(v) ? null : 'Invalid email';
                  },
                  index: showGymName ? 4 : 3,
                ),
                const SizedBox(height: 16),
                AnimatedFormField(
                  controller: widget.passwordController,
                  hintText: 'Password',
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return v.length >= 6 ? null : 'Min 6 chars';
                  },
                  index: showGymName ? 5 : 4,
                ),
                const SizedBox(height: 16),
                AnimatedFormField(
                  controller: widget.confirmController,
                  hintText: 'Confirm Password',
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return v == widget.passwordController.text ? null : 'Passwords do not match';
                  },
                  index: showGymName ? 6 : 5,
                ),
                const SizedBox(height: 24),
                widget.loading
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                        onTap: widget.onRegister,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: AppColors.accentYellow,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentYellow.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Sign Up',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.textOnAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate().shimmer(duration: 800.ms),
                          ),
                        ).animate().scaleXY(begin: 0.98, end: 1.0, duration: 200.ms, curve: Curves.easeOut),
                      ),
              ],
            ),
          ),
        ),
        ConfettiSuccess(show: widget.showConfetti),
      ],
    );
  }
}