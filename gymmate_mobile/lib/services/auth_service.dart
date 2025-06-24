import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String? _token;
  String? _userId;
  bool _isInitialized = false;

  String? get token => _token;
  String? get userId => _userId;

  Future<void> saveSession(Map<String, dynamic> sessionData) async {
    print('💾 AuthService.saveSession() called with data: $sessionData');
    
    _token = sessionData['token'];
    _userId = sessionData['user']?['id'];
    _isInitialized = true; // Mark as initialized after saving session
    
    print('💾 Extracted token: $_token');
    print('💾 Extracted userId: $_userId');
    
    // Store token with consistent key
    await _storage.write(key: 'authToken', value: _token);
    await _storage.write(key: 'user_id', value: _userId);
    
    // Store user data
    if (sessionData['user'] != null) {
      final user = sessionData['user'];
      await _storage.write(key: 'user', value: jsonEncode(user));
      
      // Store individual user fields that the home page expects
      await _storage.write(key: 'userRole', value: user['role']);
      await _storage.write(key: 'userEmail', value: user['email']);
      await _storage.write(key: 'userName', value: user['name']);
      if (user['gymId'] != null) {
        await _storage.write(key: 'gymId', value: user['gymId']);
      }
      
      print('💾 Stored userRole: ${user['role']}');
      print('💾 Stored userEmail: ${user['email']}');
      print('💾 Stored userName: ${user['name']}');
    }
    
    // Debug print
    final savedToken = await _storage.read(key: 'authToken');
    final savedRole = await _storage.read(key: 'userRole');
    print('🔑 Saved token in storage: $savedToken');
    print('🔑 Saved role in storage: $savedRole');
    notifyListeners();
  }

  Future<bool> isLoggedIn() async {
    print('🔐 AuthService.isLoggedIn() called');
    
    // If already initialized, return cached result
    if (_isInitialized) {
      print('🔐 AuthService.isLoggedIn() - using cached result: ${_token != null}');
      return _token != null;
    }
    
    try {
      _token = await _storage.read(key: 'authToken');
      _userId = await _storage.read(key: 'user_id');
      _isInitialized = true;
      
      print('🔐 AuthService.isLoggedIn() - token: $_token');
      print('🔐 AuthService.isLoggedIn() - userId: $_userId');
      
      if (_token != null) {
        print('🔐 AuthService.isLoggedIn() - returning true');
        notifyListeners();
        return true;
      } else {
        print('🔐 AuthService.isLoggedIn() - returning false (no token)');
        return false;
      }
    } catch (e) {
      print('❌ AuthService.isLoggedIn() - error: $e');
      _isInitialized = true; // Mark as initialized even on error
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Also clear FlutterSecureStorage
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'authToken');
  }

  Future<Map<String, dynamic>?> getUser() async {
    final userJson = await _storage.read(key: 'user');
    if (userJson == null) return null;
    return jsonDecode(userJson) as Map<String, dynamic>;
  }

  Future<String?> getRole() async {
    final user = await getUser();
    return user?['role'];
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    print('🔑 AuthService.login() called with email: $email');
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    print('🔑 Login response status: ${response.statusCode}');
    print('🔑 Login response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('🔑 Parsed login data: $data');
      print('🔑 Token from response: ${data['token']}');
      print('🔑 User from response: ${data['user']}');
      
      await saveSession(data);
      return data;
    } else {
      print('❌ Login failed: ${response.body}');
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'inviteCode': inviteCode,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await getUser();
  }
} 