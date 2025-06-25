import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userRole;
  String? _userName;
  String? _userEmail;
  String? _gymName;
  bool? _hasCompletedOnboarding;

  final _storage = const FlutterSecureStorage();

  bool get isAuth => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get userRole => _userRole;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get gymName => _gymName;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding ?? false;

  Future<bool> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
    print('🔑 [AuthProvider] Login started for $email');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      print('🔑 [AuthProvider] Login response: ${response.statusCode} ${response.body}');
      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        print('🔑 [AuthProvider] Login failed: ${responseData['message']}');
        throw Exception(responseData['message'] ?? 'Failed to login');
      }

      _token = responseData['token'];
      final user = responseData['user'];
      _userId = user['id'];
      _userRole = user['role'];
      _userName = user['name'];
      _userEmail = user['email'];
      _gymName = user['gymName'];
      _hasCompletedOnboarding = user['hasCompletedOnboarding'] ?? false;

      await _storage.write(key: 'user_token', value: _token);
      await _storage.write(key: 'user_id', value: _userId);
      await _storage.write(key: 'user_role', value: _userRole);
      await _storage.write(key: 'user_name', value: _userName);
      await _storage.write(key: 'user_email', value: _userEmail);
      await _storage.write(key: 'gym_name', value: _gymName);
      await _storage.write(key: 'has_completed_onboarding', value: _hasCompletedOnboarding.toString());
      
      print('🔒 [AuthProvider] Login successful, token stored. Notifying listeners.');
      notifyListeners();
      return true;
    } catch (e) {
      print('🔑 [AuthProvider] Login error: $e');
      rethrow;
    }
  }

  Future<bool> tryAutoLogin() async {
    print('🔄 [AuthProvider] Attempting auto-login...');
    final token = await _storage.read(key: 'user_token');
    if (token == null) {
      print('🔄 [AuthProvider] No token found for auto-login.');
      return false;
    }

    // Reconstruct the user object from stored data
    final user = {
      'id': await _storage.read(key: 'user_id'),
      'role': await _storage.read(key: 'user_role'),
      'name': await _storage.read(key: 'user_name'),
      'email': await _storage.read(key: 'user_email'),
      'gymName': await _storage.read(key: 'gym_name'),
      'hasCompletedOnboarding': await _storage.read(key: 'has_completed_onboarding'),
    };

    _token = token;
    _userId = user['id'];
    _userRole = user['role'];
    _userName = user['name'];
    _userEmail = user['email'];
    _gymName = user['gymName'];
    _hasCompletedOnboarding = user['hasCompletedOnboarding'] == 'true';

    print('🔄 [AuthProvider] Token found, auto-login successful. Notifying listeners.');
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    print('Logging out user...');
    _token = null;
    _userId = null;
    _userRole = null;
    _userName = null;
    _userEmail = null;
    _gymName = null;
    _hasCompletedOnboarding = null;
    
    // Immediately notify listeners to update UI
    notifyListeners();

    await _storage.deleteAll();
    print('✅ User session cleared from secure storage.');
    // Call notifyListeners again in case storage clear is async
    notifyListeners();
  }

  Future<bool> register(Map<String, dynamic> registrationData) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');
    print('🔑 [AuthProvider] Registration started for [32m${registrationData['email']}[0m');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(registrationData),
      );
      print('🔑 [AuthProvider] Registration response: ${response.statusCode} ${response.body}');
      final responseData = json.decode(response.body);

      if (response.statusCode != 201) {
        print('🔑 [AuthProvider] Registration failed: ${responseData['error'] ?? responseData['message']}');
        throw Exception(responseData['error'] ?? responseData['message'] ?? 'Failed to register');
      }

      // TEMPORARY: Wait for backend to commit user before login
      await Future.delayed(const Duration(seconds: 1));

      // Registration successful, now log in
      final loginSuccess = await login(registrationData['email'], registrationData['password']);
      return loginSuccess;
    } catch (e) {
      print('🔑 [AuthProvider] Registration error: $e');
      rethrow;
    }
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _storage.write(key: 'has_completed_onboarding', value: 'true');
    notifyListeners();
  }
} 