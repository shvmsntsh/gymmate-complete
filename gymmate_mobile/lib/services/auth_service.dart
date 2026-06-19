import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_client.dart';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  String? _token;
  String? _userId;
  bool _isInitialized = false;

  String? get token => _token;
  String? get userId => _userId;

  Future<void> saveSession(Map<String, dynamic> sessionData) async {
    _token = sessionData['token'];
    _userId = sessionData['user']?['id'];
    _isInitialized = true; // Mark as initialized after saving session

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
    }
  }

  Future<bool> isLoggedIn() async {
    // If already initialized, return cached result
    if (_isInitialized) {
      return _token != null;
    }

    try {
      _token = await _storage.read(key: 'authToken');
      _userId = await _storage.read(key: 'user_id');
      _isInitialized = true;

      if (_token != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
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
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(ApiClient.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      await saveSession(data);
      return data;
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'inviteCode': inviteCode,
          }),
        )
        .timeout(ApiClient.timeout);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await getUser();
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String? token,
  }) async {
    if (token == null) {
      throw Exception('Authentication token not found.');
    }
    final response = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}/api/user/profile'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': name, 'email': email}),
        )
        .timeout(ApiClient.timeout);
    if (response.statusCode == 200) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes));
      return decodedBody;
    } else {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  Future<String> uploadProfilePicture({
    required String imageData,
    required String? token,
  }) async {
    if (token == null) {
      throw Exception('Authentication token not found.');
    }
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/profile-picture'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'imageData': imageData}),
        )
        .timeout(ApiClient.timeout);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['profilePicture'] ?? imageData;
    } else {
      throw Exception('Failed to upload profile picture: ${response.body}');
    }
  }

  Future<void> changePassword({
    required String? currentPassword,
    required String newPassword,
    required String? token,
  }) async {
    if (token == null) {
      throw Exception('Authentication token not found.');
    }
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/password'),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            if (currentPassword != null) 'currentPassword': currentPassword,
            'newPassword': newPassword,
          }),
        )
        .timeout(ApiClient.timeout);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update password.');
    }
  }
}
