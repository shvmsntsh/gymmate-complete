import 'dart:io';
import 'package:flutter/material.dart';
import '../api/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();


  void _login() async {
    setState(() {
      _isLoading = true;
    });

    final url = Uri.parse(ApiConfig.loginUrl);
    print('🌍 Login API URL: $url');

    try {
      final resp = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': _emailCtrl.text.trim(),
              'password': _passwordCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      print('📥 Response Status: ${resp.statusCode}');
      print('📥 Response Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        print('🔓 Parsed login response: $data');

        final token = data['token'] as String?;
        final role = data['role'] as String?;
        final gymId = data['gymId'] as String?;
        if (token != null && role != null && gymId != null) {
          // Persist the token, role, and gymId
          await _storage.write(key: 'authToken', value: token);
          await _storage.write(key: 'userRole', value: role);
          await _storage.write(key: 'gymId', value: gymId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final error = jsonDecode(resp.body);
        _showError('Login failed: ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

@override
Widget build(BuildContext context) {
  final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
  final theme = ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
    cardColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  return Theme(
    data: theme,
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: const Text('T3 Fitness - Login'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Card(
              color: theme.cardColor,
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome Back 👋',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Login to access your dashboard',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 36),
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: const Icon(Icons.login),
                        label: _isLoading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Login'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          child: const Text('Register'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}