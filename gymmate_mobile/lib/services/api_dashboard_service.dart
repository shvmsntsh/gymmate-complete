import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

class DashboardService {
  static Future<Map<String, dynamic>> fetchDashboardStats(String token) async {
    print('🔍 Fetching dashboard stats...');
    print('🔗 URL: ${ApiConfig.baseUrl}/api/auth/dashboard/stats');
    print('🎫 Token: $token');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/dashboard/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📥 Response status code: ${response.statusCode}');
    print('📄 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Parsed dashboard stats: $data');
      return data;
    } else {
      print('❌ Failed to load dashboard stats: ${response.body}');
      throw Exception('Failed to load dashboard stats');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCategorizedMembers(String token) async {
    print('🔍 Fetching categorized members...');
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/members/categorized'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    print('📥 Response status code: ${response.statusCode}');
    print('📄 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Parsed categorized members: $data');
      return List<Map<String, dynamic>>.from(data['gymOwners']);
    } else {
      print('❌ Failed to load categorized members: ${response.body}');
      throw Exception('Failed to load categorized members');
    }
  }
} 