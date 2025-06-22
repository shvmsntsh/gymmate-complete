import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymmate_mobile/api/api_config.dart';

class OnboardingService {
  final String? _token;

  OnboardingService([this._token]);

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
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/status'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> startOnboarding() {
    return _performRequest((token) => http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/start'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> saveStepProgress(int step, Map<String, dynamic> data) {
     return _performRequest((token) => http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/step'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'step': step, 'data': data}),
    ));
  }
  
  Future<Map<String, dynamic>> completeOnboarding() {
    return _performRequest((token) => http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/complete'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }
  
  Future<Map<String, dynamic>> getUserBadges() {
     return _performRequest((token) => http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/badges'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }

  Future<Map<String, dynamic>> getUserProgress() {
    return _performRequest((token) => http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/progress'),
      headers: {'Authorization': 'Bearer $token'},
    ));
  }
  
  Future<Map<String, dynamic>> resetOnboarding() async {
    final data = await _performRequest((token) => http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/onboarding/reset'),
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