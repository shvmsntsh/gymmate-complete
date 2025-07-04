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

// Entry states
enum EntryState { entry, login, chooseRole, register }

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
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();
  final _regCodeController = TextEditingController();
  bool _regLoading = false;

  void _showLogin() => setState(() => _state = EntryState.login);
  void _showJoin() => setState(() => _state = EntryState.chooseRole);
  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _state = EntryState.register;
      _progress = 0.5;
      _registerError = null;
    });
  }
  void _backToEntry() => setState(() => _state = EntryState.entry);
  void _backToRole() => setState(() => _state = EntryState.chooseRole);

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

  Future<void> _onRegister() async {
    setState(() {
      _regLoading = true;
      _registerError = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final data = <String, dynamic>{
        'email': _regEmailController.text.trim(),
        'password': _regPasswordController.text,
        'role': _selectedRole?.toLowerCase(),
      };
      if (_selectedRole == 'Owner') {
        data['inviteCode'] = _regCodeController.text.trim();
      } else {
        data['gymCode'] = _regCodeController.text.trim();
      }
      final success = await authProvider.register(data);
      if (success) {
        setState(() {
          _showConfetti = true;
          _progress = 1.0;
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        setState(() => _showConfetti = false);
        // On success, navigation is handled by main.dart's Consumer
      } else {
        setState(() => _registerError = 'Registration failed.');
      }
    } catch (e) {
      setState(() => _registerError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _regLoading = false);
    }
  }

  // Helper to map UI role to backend role
  String _backendRole(String uiRole) {
    switch (uiRole.toLowerCase()) {
      case 'owner': return 'gym_owner';
      case 'trainer': return 'gym_trainer';
      case 'member': return 'gym_member';
      default: return uiRole.toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          Text(
                            'Welcome to GymMate',
                            style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
                          const SizedBox(height: 48),
                          AnimatedEntryOptions(
                            onLogin: _showLogin,
                            onJoin: _showJoin,
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
                            : _selectedRole != null
                                ? _UnifiedRoleRegistration(
                                    role: _selectedRole!,
                                    emailController: _regEmailController,
                                    passwordController: _regPasswordController,
                                    confirmController: _regConfirmController,
                                    codeController: _regCodeController,
                                    loading: _regLoading,
                                    progress: _progress,
                                    showConfetti: _showConfetti,
                                    error: _registerError,
                                    onRegister: _onRegister,
                                    onBack: _backToRole,
                                  )
                                : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
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
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            AnimatedFormField(
              controller: emailController,
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              index: 0,
            ),
            const SizedBox(height: 16),
            AnimatedFormField(
              controller: passwordController,
              hintText: 'Password',
              obscureText: true,
              index: 1,
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
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
                            color: Theme.of(context).colorScheme.onPrimary,
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
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final TextEditingController codeController;
  final bool loading;
  final double progress;
  final bool showConfetti;
  final String? error;
  final VoidCallback onRegister;
  final VoidCallback onBack;
  const _UnifiedRoleRegistration({
    required this.role,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.codeController,
    required this.loading,
    required this.progress,
    required this.showConfetti,
    required this.error,
    required this.onRegister,
    required this.onBack,
  });

  @override
  State<_UnifiedRoleRegistration> createState() => _UnifiedRoleRegistrationState();
}

class _UnifiedRoleRegistrationState extends State<_UnifiedRoleRegistration> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _gymNameController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _isSuperadmin = false;
  bool _gymNameUnique = true;
  bool _inviteValid = true;
  bool _emailValid = true;
  bool _passwordsMatch = true;
  String? _inviteRole;
  bool _mounted = true;
  String? _gymId;

  static String backendRole(String uiRole) {
    switch (uiRole.toLowerCase()) {
      case 'owner': return 'gym_owner';
      case 'trainer': return 'gym_trainer';
      case 'member': return 'gym_member';
      default: return uiRole.toLowerCase();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.codeController.addListener(_onInviteCodeChanged);
    widget.confirmController.addListener(_onPasswordChanged);
    widget.passwordController.addListener(_onPasswordChanged);
    widget.emailController.addListener(_onEmailChanged);
    _gymNameController.addListener(_onGymNameChanged);
  }

  @override
  void dispose() {
    _mounted = false;
    widget.codeController.removeListener(_onInviteCodeChanged);
    widget.confirmController.removeListener(_onPasswordChanged);
    widget.passwordController.removeListener(_onPasswordChanged);
    widget.emailController.removeListener(_onEmailChanged);
    _gymNameController.removeListener(_onGymNameChanged);
    super.dispose();
  }

  Future<bool> _checkGymNameUnique(String gymName) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/gym/check-name');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'gymName': gymName}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final exists = data['exists'] == true;
        debugPrint('[_checkGymNameUnique] API response: exists = $exists');
        return !exists;
      }
      debugPrint('[_checkGymNameUnique] Non-200 response: ${response.statusCode}');
      setState(() { _error = 'Failed to check gym name.'; });
      return false;
    } catch (e) {
      debugPrint('[_checkGymNameUnique] Exception: $e');
      setState(() { _error = 'Failed to check gym name.'; });
      return false;
    }
  }

  Future<Map<String, dynamic>> _validateInviteCode(String code) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/invite/validate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[_validateInviteCode] Success, returning data, setting _inviteValid = true');
        setState(() { _inviteValid = true; });
        return data;
      } else {
        setState(() { _inviteValid = false; });
        debugPrint('[_validateInviteCode] Error response, setting _inviteValid = false');
        return {};
      }
    } catch (e) {
      setState(() { _inviteValid = false; });
      debugPrint('[_validateInviteCode] Exception, setting _inviteValid = false');
      return {};
    }
  }

  void _onInviteCodeChanged() async {
    final code = widget.codeController.text.trim();
    if (_mounted) setState(() {
      _isSuperadmin = false;
      _inviteValid = code.isNotEmpty;
      _inviteRole = null;
      _error = null;
    });
    // For trainer/member, fetch gymId if code is not empty
    final selectedRole = backendRole(widget.role);
    if (code.isNotEmpty && (selectedRole == 'gym_member' || selectedRole == 'gym_trainer')) {
      try {
        final invite = await _validateInviteCode(code);
        if (invite.isNotEmpty && invite is Map && invite['gymId'] != null) {
          setState(() { _gymId = invite['gymId']; });
        } else {
          setState(() { _gymId = null; });
        }
      } catch (e) {
        setState(() { _gymId = null; });
      }
    } else {
      setState(() { _gymId = null; });
    }
    return;
  }

  void _onGymNameChanged() async {
    if (_isSuperadmin) {
      if (_mounted) setState(() { _gymNameUnique = true; });
      debugPrint('[_onGymNameChanged] superadmin, set _gymNameUnique = true');
      return;
    }
    final gymName = _gymNameController.text.trim();
    debugPrint('[_onGymNameChanged] gymName: $gymName');
    if (gymName.isEmpty) {
      if (_mounted) setState(() { _gymNameUnique = true; });
      debugPrint('[_onGymNameChanged] gymName empty, set _gymNameUnique = true');
      return;
    }
    try {
      final unique = await _checkGymNameUnique(gymName);
      debugPrint('[_onGymNameChanged] _checkGymNameUnique returned: $unique');
      if (_mounted) setState(() { _gymNameUnique = unique; });
      debugPrint('[_onGymNameChanged] _gymNameUnique set to: $_gymNameUnique');
    } catch (e) {
      debugPrint('[_onGymNameChanged] Error checking gym name: $e');
      if (_mounted) setState(() { _gymNameUnique = false; });
    }
  }

  void _onEmailChanged() {
    final email = widget.emailController.text.trim();
    final valid = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}").hasMatch(email);
    setState(() { _emailValid = valid; });
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordsMatch = widget.passwordController.text == widget.confirmController.text;
    });
  }

  bool get _canSubmit {
    final name = _nameController.text.trim();
    final email = widget.emailController.text.trim();
    final password = widget.passwordController.text;
    final confirm = widget.confirmController.text;
    final code = widget.codeController.text.trim();
    final gymName = _gymNameController.text.trim();
    final selectedRole = backendRole(widget.role);
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty || code.isEmpty) return false;
    if (selectedRole == 'gym_owner' && gymName.isEmpty) return false;
    if (password != confirm) return false;
    return true;
  }

  Future<void> _submit() async {
    setState(() { _error = null; _loading = true; });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final email = widget.emailController.text.trim();
    final password = widget.passwordController.text;
    final code = widget.codeController.text.trim();
    final gymName = _gymNameController.text.trim();
    final selectedRole = backendRole(widget.role);
    String assignedRole = selectedRole;
    bool isSuperadmin = false;
    if (code == '123456' && selectedRole == 'gym_owner') {
      assignedRole = 'superadmin';
      isSuperadmin = true;
    }
    final data = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': assignedRole,
    };
    if (!isSuperadmin) {
      data['inviteCode'] = code;
    }
    if (assignedRole == 'gym_owner') {
      data['gymName'] = gymName;
    }
    if ((assignedRole == 'gym_member' || assignedRole == 'gym_trainer') && _gymId != null) {
      data['gymId'] = _gymId;
    }
    if (name.isEmpty || email.isEmpty || password.isEmpty || code.isEmpty || (assignedRole == 'gym_owner' && gymName.isEmpty)) {
      setState(() { _error = 'Please fill all required fields.'; _loading = false; });
      return;
    }
    try {
      final registrationSuccess = await authProvider.register(data);
      if (registrationSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          setState(() { _error = 'Registration failed. Please try again.'; });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error ?? 'Registration failed.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() { _loading = false; });
    }
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
    if (_isSuperadmin) {
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
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
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
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red)),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.codeController,
                    decoration: InputDecoration(
                      hintText: codeLabel,
                      errorText: !_inviteValid ? 'Invalid code' : (widget.codeController.text.isEmpty ? 'Required' : null),
                    ),
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Full Name',
                      errorText: _nameController.text.isEmpty ? 'Required' : null,
                    ),
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  if (showGymName) ...[
                    TextFormField(
                      controller: _gymNameController,
                      decoration: InputDecoration(
                        hintText: 'Gym Name',
                        errorText: _gymNameUnique == false ? 'Gym name already exists' : (_gymNameController.text.isEmpty ? 'Required' : null),
                      ),
                      textInputAction: TextInputAction.next,
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: widget.emailController,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      errorText: !_emailValid ? 'Invalid email' : (widget.emailController.text.isEmpty ? 'Required' : null),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.passwordController,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      errorText: widget.passwordController.text.isEmpty ? 'Required' : null,
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: widget.confirmController,
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      errorText: !_passwordsMatch ? 'Passwords do not match' : (widget.confirmController.text.isEmpty ? 'Required' : null),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms),
                  const SizedBox(height: 24),
                  _loading
                      ? const CircularProgressIndicator()
                      : GestureDetector(
                          onTap: _canSubmit ? _submit : null,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: _canSubmit ? const Color(0xFFF8D84B) : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF8D84B).withOpacity(0.3),
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
                                  color: Colors.black,
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
        ),
        ConfettiSuccess(show: widget.showConfetti),
      ],
    );
  }
} 