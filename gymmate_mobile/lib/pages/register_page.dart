// DEPRECATED: All login/signup logic is now handled in gamified_entry_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';
import 'login_page.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/main.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  final _confirmPasswordController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _gymNameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'gym_owner'; // Default role
  bool _isSuperAdminCode = false;

  @override
  void initState() {
    super.initState();
    _inviteCodeController.addListener(_handleInviteCodeChange);
  }

  @override
  void dispose() {
    _inviteCodeController.removeListener(_handleInviteCodeChange);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _gymNameController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScaffold()),
          (route) => false,
        );
      });
    }
  }

  void _handleInviteCodeChange() {
    final isSuper = _inviteCodeController.text.trim() == '123456' && _selectedRole == 'gym_owner';
    if (isSuper != _isSuperAdminCode) {
      setState(() {
        _isSuperAdminCode = isSuper;
        if (_isSuperAdminCode) {
          _gymNameController.text = 'Alpha Gym';
        } else {
          _gymNameController.clear();
        }
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final roleForApi = _isSuperAdminCode ? 'superadmin' : _selectedRole;

      final registrationData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'role': roleForApi,
        'inviteCode': _inviteCodeController.text.trim(),
        if (roleForApi == 'gym_owner') 'gymName': _gymNameController.text.trim(),
      };

      try {
        print('🔑 [RegisterPage] Calling AuthProvider.register...');
        final registrationSuccess = await Provider.of<AuthProvider>(context, listen: false).register(registrationData);
        
        if (registrationSuccess) {
          print('🔑 [RegisterPage] Registration and auto-login successful.');
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainNavigationScaffold()),
              (route) => false,
            );
          }
        } else {
          print('🔑 [RegisterPage] Registration succeeded but auto-login failed.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Registration successful! Please log in manually.'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
            // Navigate to login page for manual login
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }
        }
      } catch (e) {
        print('🔑 [RegisterPage] Registration failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Sign Up', style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _inviteCodeController,
                              decoration: const InputDecoration(
                                hintText: 'Invite Code',
                              ),
                              style: theme.textTheme.bodyLarge,
                              validator: (value) => value == null || value.isEmpty ? 'Please enter an invite code' : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                hintText: 'Email',
                              ),
                              style: theme.textTheme.bodyLarge,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                hintText: 'Password',
                              ),
                              style: theme.textTheme.bodyLarge,
                              obscureText: true,
                              validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: const InputDecoration(
                                hintText: 'Confirm Password',
                              ),
                              style: theme.textTheme.bodyLarge,
                              obscureText: true,
                              validator: (value) => value != _passwordController.text ? 'Passwords do not match' : null,
                            ),
                            const SizedBox(height: 20),
                            Text('Role: Member', style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 32),
                            _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : ElevatedButton(
                                    onPressed: _register,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Sign Up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 600.ms, curve: Curves.easeOut),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Text(
                      'Already have an account? Sign In',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRoleButton('gym_owner', 'Gym Owner', theme),
          _buildRoleButton('gym_member', 'Gym Member', theme),
          _buildRoleButton('gym_trainer', 'Gym Trainer', theme),
        ],
      ),
    );
  }

  Widget _buildRoleButton(String role, String text, ThemeData theme) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
            _handleInviteCodeChange();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onToggleObscure,
              )
            : null,
      ),
    );
  }
}