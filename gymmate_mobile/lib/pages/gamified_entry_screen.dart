import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/main.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/widgets/animated_form_field.dart';
import 'package:gymmate_mobile/widgets/confetti_success.dart';
import 'package:gymmate_mobile/widgets/phase_one_shell.dart';
import 'package:gymmate_mobile/widgets/role_card.dart';

import 'quick_join_screen.dart';

enum EntryState { entry, login, chooseRole, register, quickJoin, forgotPassword }

class GamifiedEntryScreen extends StatefulWidget {
  final EntryState initialState;

  const GamifiedEntryScreen({Key? key, this.initialState = EntryState.entry})
    : super(key: key);

  @override
  State<GamifiedEntryScreen> createState() => _GamifiedEntryScreenState();
}

class _GamifiedEntryScreenState extends State<GamifiedEntryScreen> {
  late EntryState _state;
  String? _selectedRole;
  bool _showConfetti = false;
  double _progress = 0.0;
  String? _registerError;
  String? _loginError;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  final _resetConfirmController = TextEditingController();
  bool _loginLoading = false;
  bool _resetLoading = false;
  bool _resetCodeSent = false;
  String? _resetMessage;
  String? _resetError;

  final _regNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();
  final _regCodeController = TextEditingController();
  final _regGymNameController = TextEditingController();
  final _regPhoneNumberController = TextEditingController();
  bool _regLoading = false;

  String? _backendRole;
  String? _backendGymId;
  bool _isSuperadmin = false;
  bool? _inviteCodeValid;
  Timer? _inviteDebounce;
  String _lastVerifiedCode = '';

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _regCodeController.addListener(_scheduleInviteVerification);
  }

  @override
  void dispose() {
    _inviteDebounce?.cancel();
    _regCodeController.removeListener(_scheduleInviteVerification);
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _resetPasswordController.dispose();
    _resetConfirmController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmController.dispose();
    _regCodeController.dispose();
    _regGymNameController.dispose();
    _regPhoneNumberController.dispose();
    super.dispose();
  }

  void _showLogin() => setState(() => _state = EntryState.login);
  void _showJoin() => setState(() => _state = EntryState.chooseRole);
  void _showQuickJoin() => setState(() => _state = EntryState.quickJoin);
  void _showForgotPassword() {
    _resetEmailController.text = _loginEmailController.text.trim();
    setState(() {
      _state = EntryState.forgotPassword;
      _resetError = null;
      _resetMessage = null;
    });
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _state = EntryState.register;
      _progress = 0.35;
      _registerError = null;
      _inviteCodeValid = null;
      _backendRole = null;
      _backendGymId = null;
      _isSuperadmin = false;
      _lastVerifiedCode = '';
      _regCodeController.clear();
      _regGymNameController.clear();
    });
  }

  void _backToEntry() => setState(() => _state = EntryState.entry);

  void _backToRole() {
    _inviteDebounce?.cancel();
    _lastVerifiedCode = '';
    _regNameController.clear();
    _regEmailController.clear();
    _regPasswordController.clear();
    _regConfirmController.clear();
    _regCodeController.clear();
    _regGymNameController.clear();
    _regPhoneNumberController.clear();
    setState(() {
      _state = EntryState.chooseRole;
      _registerError = null;
      _inviteCodeValid = null;
      _backendRole = null;
      _backendGymId = null;
      _isSuperadmin = false;
      _progress = 0.0;
    });
  }

  void _scheduleInviteVerification() {
    if (_state != EntryState.register) {
      return;
    }

    final code = _regCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _inviteCodeValid = null;
        _backendRole = null;
        _backendGymId = null;
        _isSuperadmin = false;
        _registerError = null;
      });
      return;
    }

    if (code == _lastVerifiedCode) {
      return;
    }

    _inviteDebounce?.cancel();
    _inviteDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _verifyInviteCode(code);
    });
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
    } catch (e) {
      setState(() => _loginError = _friendlyEntryError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Future<void> _requestPasswordReset() async {
    setState(() {
      _resetLoading = true;
      _resetError = null;
      _resetMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final message = await authProvider.requestPasswordReset(
        _resetEmailController.text.trim(),
      );
      setState(() {
        _resetCodeSent = true;
        _resetMessage = message;
      });
    } catch (e) {
      setState(() => _resetError = _friendlyEntryError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _resetLoading = false);
      }
    }
  }

  Future<void> _completePasswordReset() async {
    final password = _resetPasswordController.text;
    final confirm = _resetConfirmController.text;
    if (password.length < 6) {
      setState(() => _resetError = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _resetError = 'Passwords do not match.');
      return;
    }

    setState(() {
      _resetLoading = true;
      _resetError = null;
      _resetMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final message = await authProvider.completePasswordReset(
        email: _resetEmailController.text.trim(),
        code: _resetCodeController.text.trim(),
        newPassword: password,
      );
      _loginEmailController.text = _resetEmailController.text.trim();
      _loginPasswordController.clear();
      setState(() {
        _state = EntryState.login;
        _loginError = message;
        _resetCodeSent = false;
        _resetCodeController.clear();
        _resetPasswordController.clear();
        _resetConfirmController.clear();
      });
    } catch (e) {
      setState(() => _resetError = _friendlyEntryError(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _resetLoading = false);
      }
    }
  }

  Future<void> _verifyInviteCode(String code) async {
    setState(() => _registerError = null);
    code = code.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _isSuperadmin = false;
        _backendRole = null;
        _backendGymId = null;
        _inviteCodeValid = null;
      });
      return;
    }

    if (code == '123456') {
      _lastVerifiedCode = code;
      setState(() {
        _isSuperadmin = true;
        _backendRole = 'superadmin';
        _inviteCodeValid = true;
        _regGymNameController.text = 'GymMate HQ';
        _registerError = null;
        _progress = 0.7;
      });
      return;
    }

    if (_isSuperadmin) {
      setState(() {
        _isSuperadmin = false;
        _backendRole = null;
        _inviteCodeValid = null;
        _regGymNameController.clear();
      });
    }

    try {
      setState(() => _regLoading = true);
      final url = Uri.parse('${ApiConfig.baseUrl}/api/invite/validate');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String expectedRole = '';
        if (_selectedRole != null) {
          final selected = _selectedRole!.toLowerCase();
          if (selected == 'owner') {
            expectedRole = 'gym_owner';
          } else if (selected == 'trainer') {
            expectedRole = 'gym_trainer';
          } else if (selected == 'member') {
            expectedRole = 'gym_member';
          }
        }

        if (expectedRole.isNotEmpty && data['role'] != expectedRole) {
          setState(() {
            _backendRole = null;
            _backendGymId = null;
            _inviteCodeValid = false;
            _registerError = 'Invite code does not match this role.';
          });
          return;
        }

        _lastVerifiedCode = code;
        final invitee = (data['invitee'] is Map)
            ? Map<String, dynamic>.from(data['invitee'])
            : const <String, dynamic>{};
        final inviteeName = invitee['name']?.toString().trim() ?? '';
        final inviteeEmail = invitee['email']?.toString().trim() ?? '';
        final inviteePhone = invitee['phone_number']?.toString().trim() ?? '';
        if (inviteeName.isNotEmpty) _regNameController.text = inviteeName;
        if (inviteeEmail.isNotEmpty) _regEmailController.text = inviteeEmail;
        if (inviteePhone.isNotEmpty) _regPhoneNumberController.text = inviteePhone;
        setState(() {
          _backendRole = data['role'];
          _backendGymId = data['gymId'];
          _inviteCodeValid = true;
          _registerError = null;
          _progress = 0.7;
        });
      } else {
        setState(() {
          _backendRole = null;
          _backendGymId = null;
          _inviteCodeValid = false;
          _registerError = 'Invite code is invalid or used.';
        });
      }
    } catch (_) {
      setState(() {
        _backendRole = null;
        _backendGymId = null;
        _inviteCodeValid = false;
        _registerError = 'Could not verify the invite code.';
      });
    } finally {
      if (mounted) {
        setState(() => _regLoading = false);
      }
    }
  }

  Future<void> _onRegister() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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

    if (name.isEmpty) errors.add('Name is required');
    if (email.isEmpty) {
      errors.add('Email is required');
    } else if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)) {
      errors.add('Invalid email format');
    }
    if (password.isEmpty) {
      errors.add('Password is required');
    } else if (password.length < 6) {
      errors.add('Password must be at least 6 characters');
    }
    if (confirm.isEmpty) {
      errors.add('Confirm password is required');
    } else if (password != confirm) {
      errors.add('Passwords do not match');
    }
    if (code.isEmpty) errors.add('Invite code is required');
    if (phoneNumber.isEmpty) errors.add('Phone number is required');
    if ((role == 'owner' || _isSuperadmin || _backendRole == 'gym_owner') &&
        gymName.isEmpty) {
      errors.add('Gym name is required');
    }

    if (errors.isNotEmpty) {
      setState(() => _registerError = errors.first);
      return;
    }

    if (!_isSuperadmin && (_backendRole == null || code != _lastVerifiedCode)) {
      await _verifyInviteCode(code);
      if (_registerError != null || (_backendRole == null && !_isSuperadmin)) {
        return;
      }
    }

    setState(() {
      _regLoading = true;
      _registerError = null;
      _progress = 0.92;
    });

    try {
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
      } else if (_backendRole == 'gym_trainer' ||
          _backendRole == 'gym_member') {
        data['role'] = _backendRole;
        data['inviteCode'] = code;
        if (_backendGymId != null) {
          data['gymId'] = _backendGymId;
        }
      } else {
        data['role'] = role == 'owner'
            ? 'gym_owner'
            : role == 'trainer'
            ? 'gym_trainer'
            : 'gym_member';
        data['inviteCode'] = code;
      }

      final success = await authProvider.register(data);
      if (success) {
        setState(() {
          _showConfetti = true;
          _progress = 1;
        });
        await Future.delayed(const Duration(milliseconds: 1600));
        if (!mounted) return;
        setState(() => _showConfetti = false);
      } else {
        setState(() => _registerError = 'Registration failed.');
      }
    } catch (e) {
      final message = _friendlyEntryError(e.toString());
      if (message.contains('Superadmin already exists')) {
        setState(() => _registerError = 'Superadmin already exists.');
      } else if (message.contains('already used invitation code') ||
          message.contains('Invite code is invalid or used')) {
        setState(() => _registerError = 'Invite code is invalid or used.');
      } else if (message.contains(
        'An account with this email already exists',
      )) {
        setState(
          () => _registerError = 'An account with this email already exists.',
        );
      } else {
        setState(() => _registerError = message);
      }
    } finally {
      if (mounted) {
        setState(() => _regLoading = false);
      }
    }
  }

  String _friendlyEntryError(String raw) {
    final message = raw.replaceFirst('Exception: ', '');
    if (message.contains('403') ||
        message.toLowerCase().contains('invalid or expired token')) {
      return 'Your session expired. Please sign in again.';
    }
    if (message.contains('This invite code does not match')) {
      return 'Invite code does not match this role.';
    }
    if (message.contains('Invalid or already used invite code')) {
      return 'Invite code is invalid or used.';
    }
    if (message.contains('Failed with status')) {
      return 'We could not finish that right now. Please try again.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) =>
                    MainNavigationScaffold(key: MainNavigationScaffold.navKey),
              ),
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PhaseOneScaffold(
          denserGlow: _state == EntryState.entry,
          scrollable: true,
          child: Stack(
            children: [
              PhaseOnePageFrame(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: switch (_state) {
                    EntryState.entry => _EntryLanding(
                      key: const ValueKey('entry'),
                      onLogin: _showLogin,
                      onJoin: _showJoin,
                      onQuickJoin: _showQuickJoin,
                    ),
                    EntryState.login => _LoginStateView(
                      key: const ValueKey('login'),
                      emailController: _loginEmailController,
                      passwordController: _loginPasswordController,
                      loading: _loginLoading,
                      error: _loginError,
                      onLogin: _onLogin,
                      onBack: _backToEntry,
                      onForgot: _showForgotPassword,
                    ),
                    EntryState.forgotPassword => _ForgotPasswordView(
                      key: const ValueKey('forgot-password'),
                      emailController: _resetEmailController,
                      codeController: _resetCodeController,
                      passwordController: _resetPasswordController,
                      confirmController: _resetConfirmController,
                      codeSent: _resetCodeSent,
                      loading: _resetLoading,
                      message: _resetMessage,
                      error: _resetError,
                      onRequestCode: _requestPasswordReset,
                      onCompleteReset: _completePasswordReset,
                      onBack: _showLogin,
                    ),
                    EntryState.chooseRole => _RoleSelectionView(
                      key: const ValueKey('role'),
                      selectedRole: _selectedRole,
                      onSelect: _selectRole,
                      onBack: _backToEntry,
                    ),
                    EntryState.quickJoin => QuickJoinScreen(
                      onBack: _backToEntry,
                    ),
                    EntryState.register => _RegistrationView(
                      key: const ValueKey('register'),
                      role: _selectedRole ?? 'Member',
                      nameController: _regNameController,
                      emailController: _regEmailController,
                      passwordController: _regPasswordController,
                      confirmController: _regConfirmController,
                      codeController: _regCodeController,
                      gymNameController: _regGymNameController,
                      phoneNumberController: _regPhoneNumberController,
                      loading: _regLoading,
                      progress: _progress,
                      error: _registerError,
                      inviteCodeValid: _inviteCodeValid,
                      backendRole: _backendRole,
                      isSuperadmin: _isSuperadmin,
                      onRegister: _onRegister,
                      onBack: _backToRole,
                    ),
                  },
                ),
              ),
              ConfettiSuccess(show: _showConfetti),
            ],
          ),
        );
      },
    );
  }
}

class _EntryLanding extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onJoin;
  final VoidCallback onQuickJoin;

  const _EntryLanding({
    super.key,
    required this.onLogin,
    required this.onJoin,
    required this.onQuickJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PhaseOneTopBar(),
        const SizedBox(height: 20),
        _HeroPanel(onLogin: onLogin, onJoin: onJoin, onQuickJoin: onQuickJoin),
        const PhaseOneFooterNote(),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onJoin;
  final VoidCallback onQuickJoin;

  const _HeroPanel({
    required this.onLogin,
    required this.onJoin,
    required this.onQuickJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PhaseOneSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PhaseOneBadge(label: 'Start Your Session'),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              text: 'Track. Train. ',
              style: theme.textTheme.displayLarge,
              children: [
                TextSpan(
                  text: 'Stay consistent.',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Log workouts, follow your plan, and stay connected every day.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _MetricChip(value: 'Daily', label: 'Workout Logs'),
              _MetricChip(value: 'Coach', label: 'Trainer Chat'),
              _MetricChip(value: 'Week', label: 'Progress View'),
            ],
          ),
          const SizedBox(height: 22),
          PhaseOnePrimaryButton(label: 'Continue Training', onTap: onLogin),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onJoin, child: const Text('Join Your Gym')),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onQuickJoin,
              child: const Text('First-time invite access'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08, end: 0);
  }
}

class _MetricChip extends StatelessWidget {
  final String value;
  final String label;

  const _MetricChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginStateView extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onLogin;
  final VoidCallback onBack;
  final VoidCallback onForgot;

  const _LoginStateView({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.error,
    required this.onLogin,
    required this.onBack,
    required this.onForgot,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhaseOneTopBar(onBack: onBack),
          const SizedBox(height: 16),
          PhaseOneSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhaseOneBadge(label: 'Gym Access'),
                const SizedBox(height: 14),
                const PhaseOneSectionTitle(
                  eyebrow: 'Log In',
                  title: 'Welcome back.',
                  subtitle: 'Sign in and jump back into your day.',
                ),
                const SizedBox(height: 18),
                if (error != null) ...[
                  PhaseOneStatusBanner(message: error!),
                  const SizedBox(height: 14),
                ],
                AnimatedFormField(
                  controller: emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)
                        ? null
                        : 'Invalid email';
                  },
                  index: 0,
                ),
                const SizedBox(height: 12),
                AnimatedFormField(
                  controller: passwordController,
                  hintText: 'Password',
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return v.length >= 6 ? null : 'Min 6 chars';
                  },
                  index: 1,
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onForgot,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 10),
                PhaseOnePrimaryButton(
                  label: 'Log In',
                  onTap: onLogin,
                  loading: loading,
                ),
              ],
            ),
          ),
          const PhaseOneFooterNote(),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08, end: 0);
  }
}

class _ForgotPasswordView extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController codeController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool codeSent;
  final bool loading;
  final String? message;
  final String? error;
  final VoidCallback onRequestCode;
  final VoidCallback onCompleteReset;
  final VoidCallback onBack;

  const _ForgotPasswordView({
    super.key,
    required this.emailController,
    required this.codeController,
    required this.passwordController,
    required this.confirmController,
    required this.codeSent,
    required this.loading,
    required this.message,
    required this.error,
    required this.onRequestCode,
    required this.onCompleteReset,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhaseOneTopBar(onBack: onBack),
          const SizedBox(height: 16),
          PhaseOneSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhaseOneBadge(label: 'Password Reset'),
                const SizedBox(height: 14),
                const PhaseOneSectionTitle(
                  eyebrow: 'Account Recovery',
                  title: 'Reset your password.',
                  subtitle:
                      'Use your account email and the code from your inbox.',
                ),
                const SizedBox(height: 18),
                if (error != null) ...[
                  PhaseOneStatusBanner(message: error!),
                  const SizedBox(height: 14),
                ],
                if (message != null) ...[
                  Text(
                    message!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 14),
                ],
                AnimatedFormField(
                  controller: emailController,
                  hintText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)
                        ? null
                        : 'Invalid email';
                  },
                  index: 0,
                ),
                if (codeSent) ...[
                  const SizedBox(height: 12),
                  AnimatedFormField(
                    controller: codeController,
                    hintText: 'Reset Code',
                    keyboardType: TextInputType.number,
                    index: 1,
                  ),
                  const SizedBox(height: 12),
                  AnimatedFormField(
                    controller: passwordController,
                    hintText: 'New Password',
                    isPassword: true,
                    index: 2,
                  ),
                  const SizedBox(height: 12),
                  AnimatedFormField(
                    controller: confirmController,
                    hintText: 'Confirm New Password',
                    isPassword: true,
                    index: 3,
                  ),
                ],
                const SizedBox(height: 18),
                PhaseOnePrimaryButton(
                  label: codeSent ? 'Reset Password' : 'Send Reset Code',
                  onTap: codeSent ? onCompleteReset : onRequestCode,
                  loading: loading,
                ),
                if (codeSent) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: loading ? null : onRequestCode,
                      child: const Text('Send code again'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const PhaseOneFooterNote(),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08, end: 0);
  }
}

class _RoleSelectionView extends StatelessWidget {
  final String? selectedRole;
  final void Function(String) onSelect;
  final VoidCallback onBack;

  const _RoleSelectionView({
    super.key,
    required this.selectedRole,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseOneTopBar(onBack: onBack),
        const SizedBox(height: 16),
        PhaseOneSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PhaseOneBadge(label: 'Role Setup'),
              const SizedBox(height: 14),
              const PhaseOneSectionTitle(
                eyebrow: 'Choose Role',
                title: 'Choose your role.',
                subtitle: 'Pick the access that matches your gym use.',
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 640;
                  final roles = ['Owner', 'Trainer', 'Member'];

                  if (compact) {
                    return _RoleCarousel(
                      roles: roles,
                      selectedRole: selectedRole,
                      onSelect: onSelect,
                    );
                  }

                  return Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: List.generate(roles.length, (index) {
                      final role = roles[index];
                      return RoleCard(
                        title: role,
                        selected: selectedRole == role,
                        onTap: () => onSelect(role),
                        index: index,
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
        const PhaseOneFooterNote(),
      ],
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08, end: 0);
  }
}

class _RoleCarousel extends StatefulWidget {
  final List<String> roles;
  final String? selectedRole;
  final ValueChanged<String> onSelect;

  const _RoleCarousel({
    required this.roles,
    required this.selectedRole,
    required this.onSelect,
  });

  @override
  State<_RoleCarousel> createState() => _RoleCarouselState();
}

class _RoleCarouselState extends State<_RoleCarousel> {
  late final PageController _pageController;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    final rawIndex = widget.selectedRole == null
        ? 0
        : widget.roles.indexOf(widget.selectedRole!);
    final initialIndex = rawIndex < 0 ? 0 : rawIndex;
    _pageController = PageController(
      viewportFraction: 0.84,
      initialPage: initialIndex,
    );
    _page = initialIndex.toDouble();
    _pageController.addListener(_handlePageChange);
  }

  void _handlePageChange() {
    if (!_pageController.hasClients) return;
    setState(() {
      _page = _pageController.page ?? _page;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeIndex = _page.round().clamp(0, widget.roles.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Swipe to compare each workspace, then tap the card that fits your access.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.roles.length,
            itemBuilder: (context, index) {
              final role = widget.roles[index];
              final distance = (_page - index).abs().clamp(0.0, 1.0);
              final scale = 1 - (distance * 0.08);

              return AnimatedPadding(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.only(
                  right: index == widget.roles.length - 1 ? 0 : 10,
                  left: index == 0 ? 0 : 4,
                  top: 6 + (distance * 10),
                  bottom: 6 + (distance * 4),
                ),
                child: Transform.scale(
                  scale: scale,
                  child: RoleCard(
                    title: role,
                    selected:
                        widget.selectedRole == role || activeIndex == index,
                    onTap: () => widget.onSelect(role),
                    index: index,
                    fullWidth: true,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.roles.length, (index) {
            final active = activeIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RegistrationView extends StatelessWidget {
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
  final String? error;
  final bool? inviteCodeValid;
  final String? backendRole;
  final bool isSuperadmin;
  final VoidCallback onRegister;
  final VoidCallback onBack;

  const _RegistrationView({
    super.key,
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
    required this.error,
    required this.inviteCodeValid,
    required this.backendRole,
    required this.isSuperadmin,
    required this.onRegister,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final roleLabel = isSuperadmin ? 'Superadmin' : role;
    final showGymName =
        role.toLowerCase() == 'owner' ||
        isSuperadmin ||
        backendRole == 'gym_owner';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhaseOneTopBar(onBack: onBack),
          const SizedBox(height: 16),
          PhaseOneSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhaseOneBadge(label: 'Create Account'),
                const SizedBox(height: 14),
                PhaseOneSectionTitle(
                  eyebrow: roleLabel,
                  title: 'Set up your $roleLabel account.',
                  subtitle: 'Add your invite and finish setup.',
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress == 0 ? 0.35 : progress,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Invite and account setup',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (error != null) ...[
                  PhaseOneStatusBanner(message: error!),
                  const SizedBox(height: 12),
                ],
                if (inviteCodeValid == true) ...[
                  PhaseOneStatusBanner(
                    message: isSuperadmin
                        ? 'Superadmin code verified.'
                        : 'Invite verified for ${_prettyRole(backendRole)}.',
                    isError: false,
                  ),
                  const SizedBox(height: 12),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    if (stacked) {
                      return Column(children: _buildFields(showGymName));
                    }

                    return Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: _buildSplitFields(showGymName),
                    );
                  },
                ),
                const SizedBox(height: 16),
                PhaseOnePrimaryButton(
                  label: 'Create account',
                  onTap: onRegister,
                  loading: loading,
                ),
              ],
            ),
          ),
          const PhaseOneFooterNote(),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.08, end: 0);
  }

  List<Widget> _buildFields(bool showGymName) {
    final fields = <Widget>[
      AnimatedFormField(
        controller: nameController,
        hintText: 'Full Name',
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        index: 0,
      ),
      const SizedBox(height: 12),
      AnimatedFormField(
        controller: emailController,
        hintText: 'Email',
        keyboardType: TextInputType.emailAddress,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          return RegExp(r'^\S+@\S+\.\S+$').hasMatch(v) ? null : 'Invalid email';
        },
        index: 1,
      ),
      const SizedBox(height: 12),
      AnimatedFormField(
        controller: phoneNumberController,
        hintText: 'Phone Number',
        keyboardType: TextInputType.phone,
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        index: 2,
      ),
      const SizedBox(height: 12),
      AnimatedFormField(
        controller: codeController,
        hintText: 'Invite Code',
        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        isValid: inviteCodeValid,
        index: 3,
      ),
    ];

    if (showGymName) {
      fields.addAll([
        const SizedBox(height: 12),
        AnimatedFormField(
          controller: gymNameController,
          hintText: 'Gym Name',
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          index: 4,
        ),
      ]);
    }

    fields.addAll([
      const SizedBox(height: 12),
      AnimatedFormField(
        controller: passwordController,
        hintText: 'Password',
        isPassword: true,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          return v.length >= 6 ? null : 'Min 6 chars';
        },
        index: showGymName ? 5 : 4,
      ),
      const SizedBox(height: 12),
      AnimatedFormField(
        controller: confirmController,
        hintText: 'Confirm Password',
        isPassword: true,
        validator: (v) {
          if (v == null || v.isEmpty) return 'Required';
          return v == passwordController.text ? null : 'Passwords do not match';
        },
        index: showGymName ? 6 : 5,
      ),
    ]);

    return fields;
  }

  List<Widget> _buildSplitFields(bool showGymName) {
    Widget fieldBox(Widget child) {
      return SizedBox(width: 291, child: child);
    }

    final widgets = <Widget>[
      fieldBox(
        AnimatedFormField(
          controller: nameController,
          hintText: 'Full Name',
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          index: 0,
        ),
      ),
      fieldBox(
        AnimatedFormField(
          controller: emailController,
          hintText: 'Email',
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Required';
            return RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)
                ? null
                : 'Invalid email';
          },
          index: 1,
        ),
      ),
      fieldBox(
        AnimatedFormField(
          controller: phoneNumberController,
          hintText: 'Phone Number',
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          index: 2,
        ),
      ),
      fieldBox(
        AnimatedFormField(
          controller: codeController,
          hintText: 'Invite Code',
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          isValid: inviteCodeValid,
          index: 3,
        ),
      ),
    ];

    if (showGymName) {
      widgets.add(
        fieldBox(
          AnimatedFormField(
            controller: gymNameController,
            hintText: 'Gym Name',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            index: 4,
          ),
        ),
      );
    }

    widgets.addAll([
      fieldBox(
        AnimatedFormField(
          controller: passwordController,
          hintText: 'Password',
          isPassword: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            return v.length >= 6 ? null : 'Min 6 chars';
          },
          index: showGymName ? 5 : 4,
        ),
      ),
      fieldBox(
        AnimatedFormField(
          controller: confirmController,
          hintText: 'Confirm Password',
          isPassword: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            return v == passwordController.text
                ? null
                : 'Passwords do not match';
          },
          index: showGymName ? 6 : 5,
        ),
      ),
    ]);

    return widgets;
  }

  static String _prettyRole(String? role) {
    if (role == null || role.isEmpty) return 'your gym';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
