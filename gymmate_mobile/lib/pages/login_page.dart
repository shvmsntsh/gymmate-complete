import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(ApiConstants.loginEndpoint);

    try {
      print('🌐 Attempting login for ${_emailCtrl.text}');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      print('🔹 Response status: ${resp.statusCode}');
      print('🔹 Headers: ${resp.headers}');
      print('🔹 Body: ${resp.body}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final token = body['token'];

        if (token != null) {
          await _storage.write(key: 'authToken', value: token);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          _showError('Login failed: Token missing');
        }
      } else {
        final errorBody = jsonDecode(resp.body);
        _showError('Login failed: ${errorBody['message']}');
      }
    } catch (e) {
      print('❌ Exception during login: $e');
      if (e is TimeoutException) {
        print('🕓 Timeout: Request took too long to complete');
      } else if (e is SocketException) {
        print('🌐 Network error: ${e.message}');
      }
      _showError('Login failed: ${e.toString()}');
    }

    setState(() => _isLoading = false);
  }

  void _showError(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Login'),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('No account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}