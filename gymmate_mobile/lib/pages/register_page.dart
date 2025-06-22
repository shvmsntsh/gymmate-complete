import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'package:gymmate_mobile/services/auth_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final AuthService _authService = AuthService();

  bool _isGymNameDisabled = true;
  Timer? _debounce;

  String? _inviteCodeStatus;
  String? _inviteCodeMessage;

  @override
  void initState() {
    super.initState();
    _inviteCodeController.addListener(_onInviteCodeChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _onInviteCodeChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final code = _inviteCodeController.text.trim();
      if (code.isNotEmpty) {
        _validateInviteCode(code);
      } else {
        setState(() {
          _inviteCodeStatus = null;
          _inviteCodeMessage = null;
          _isGymNameDisabled = true;
          _nameController.clear();
        });
      }
    });
  }

  Future<void> _validateInviteCode(String code) async {
    // Note: In a real app, hide this URL
    final url = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/invite/validate');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final role = data['role'];
        final gymName = data['gym']?['gymName'] ?? '';
        
        setState(() {
          _inviteCodeStatus = 'valid';
          _inviteCodeMessage = 'Valid code for: $role.';
          // For superadmin, don't require gym name
          _isGymNameDisabled = role == 'superadmin' || gymName.isNotEmpty;
          if (role == 'superadmin') {
            _nameController.text = 'Super Admin'; // Default name for superadmin
          } else {
            _nameController.text = gymName;
          }
        });
      } else {
        setState(() {
          _inviteCodeStatus = 'invalid';
          _inviteCodeMessage = data['error'] ?? 'Invalid code';
          _isGymNameDisabled = true;
          _nameController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _inviteCodeStatus = 'invalid';
        _inviteCodeMessage = 'Could not reach server.';
        _isGymNameDisabled = true;
        _nameController.clear();
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Attempting registration with:');
      print('  Name: \'${_nameController.text.trim()}\'');
      print('  Email: \'${_emailController.text.trim()}\'');
      print('  InviteCode: \'${_inviteCodeController.text.trim()}\'');

      try {
        await _authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          inviteCode: _inviteCodeController.text.trim(),
        );

        print('Registration successful!');

        if (mounted) {
          // Show success and prompt to login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please log in.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(); // Go back to login page
        }
      } catch (e) {
        print('Registration error: $e');
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildInviteCodeField(),
                const SizedBox(height: 20),
                _buildGymNameField(),
                const SizedBox(height: 20),
                _buildEmailField(),
                const SizedBox(height: 20),
                _buildPasswordField(),
                const SizedBox(height: 32),
                _buildRegisterButton(),
                const SizedBox(height: 24),
                _buildLoginPrompt(),
              ],
            ).animate().fadeIn(duration: 600.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Join GymMate today!',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildInviteCodeField() {
    return TextFormField(
      controller: _inviteCodeController,
      decoration: InputDecoration(
        labelText: 'Invite Code',
        prefixIcon: const Icon(Icons.vpn_key_outlined),
        suffixIcon: _buildSuffixIcon(),
        helperText: _inviteCodeMessage,
        helperStyle: TextStyle(
          color: _inviteCodeStatus == 'valid' ? Colors.green : Colors.red,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Invite code is required';
        }
        return null;
      },
    );
  }

  Widget? _buildSuffixIcon() {
    if (_inviteCodeStatus == 'valid') {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    if (_inviteCodeStatus == 'invalid') {
      return const Icon(Icons.error, color: Colors.red);
    }
    return null;
  }
  
  Widget _buildGymNameField() {
    final isSuperadmin = _inviteCodeController.text.trim() == '123456';
    return TextFormField(
      controller: _nameController,
      enabled: !_isGymNameDisabled,
      decoration: InputDecoration(
        labelText: isSuperadmin ? 'Name' : 'Gym Name',
        prefixIcon: Icon(isSuperadmin ? Icons.person_outline : Icons.business_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isSuperadmin ? 'Name is required' : 'Gym Name is required for this invite code';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
  
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline),
      ),
      validator: (value) {
        if (value == null || value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _register,
      child: _isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
            )
          : const Text('Create Account'),
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sign In'),
        ),
      ],
    );
  }
}