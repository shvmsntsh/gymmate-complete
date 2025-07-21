import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymmate_mobile/api/api_config.dart';

class OnboardingService {
  final String baseUrl = ApiConfig.baseUrl;
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Future<String?> _getToken() async {
    if (_token != null) {
      return _token;
    }
    print('❌ OnboardingService: No auth token provided.');
    return null;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      print('❌ Service call failed with status ${response.statusCode}: ${response.body}');
      throw Exception('Failed with status ${response.statusCode}: ${response.body}');
    }
  }

  Future<T> _performRequest<T>(Future<http.Response> Function(String token) requestFunc) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Authentication token not found.');
    }
    try {
      final response = await requestFunc(token);
      return await _handleResponse(response) as T;
    } catch (e) {
      print('🚨 Service request error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOnboardingStatus() {
    return _performRequest((token) => http.get(
      Uri.parse('$baseUrl/api/onboarding/status'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> startOnboarding() {
    return _performRequest((token) => http.post(
      Uri.parse('$baseUrl/api/onboarding/start'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> saveStepProgress(int step, Map<String, dynamic> data) {
     return _performRequest((token) => http.post(
      Uri.parse('$baseUrl/api/onboarding/step'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'step': step, 'data': data}),
    ));
  }
  
  Future<void> completeOnboarding(Map<String, dynamic> data) async {
    if (_token == null) {
      throw Exception('Token not set');
    }

    final url = '$baseUrl/api/onboarding/complete';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
    final body = json.encode(data);

    print('[OnboardingService] POST $url');
    print('[OnboardingService] Headers: $headers');
    print('[OnboardingService] Body: $body');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      print('[OnboardingService] Response status: ${response.statusCode}');
      print('[OnboardingService] Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to save onboarding data: ${response.body}');
      }
    } catch (e) {
      print('Error saving onboarding data: $e');
      rethrow;
    }
  }
  
  Future<bool> checkOnboardingStatus() async {
    if (_token == null) {
      throw Exception('Token not set');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/onboarding/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['completed'] ?? false;
      } else {
        throw Exception('Failed to check onboarding status');
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getUserBadges() {
     return _performRequest((token) => http.get(
      Uri.parse('$baseUrl/api/onboarding/badges'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> getUserProgress() {
    return _performRequest((token) => http.get(
      Uri.parse('$baseUrl/api/onboarding/progress'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }
  
  Future<Map<String, dynamic>> resetOnboarding() async {
    final data = await _performRequest((token) => http.post(
      Uri.parse('$baseUrl/api/onboarding/reset'),
      headers: {'Authorization': 'Bearer $token'},
    ));
    await _clearLocalCache();
    return data;
  }

  // Local Caching Logic
  static Future<void> _clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_state');
    print('🧹 Cleared onboarding cache');
  }
}

// REMOVING DUPLICATE MODEL DEFINITIONS FROM THIS FILE
// The single source of truth is now in lib/models/