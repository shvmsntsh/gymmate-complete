import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

class ApiDashboardService {
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

  static Future<List<Map<String, dynamic>>> fetchGymRegistrationsLast7Days(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/registrations/last7days'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['registrations']);
      } else {
        throw Exception('Failed to load gym registrations');
      }
    } catch (e) {
      // Fallback to sample data
      return [
        {'day': 'Mon', 'count': 2},
        {'day': 'Tue', 'count': 4},
        {'day': 'Wed', 'count': 3},
        {'day': 'Thu', 'count': 5},
        {'day': 'Fri', 'count': 1},
        {'day': 'Sat', 'count': 6},
        {'day': 'Sun', 'count': 2},
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTrainerAttendanceProgress(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/trainer/attendance-progress'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['attendanceProgress']);
      } else {
        throw Exception('Failed to load trainer attendance/progress');
      }
    } catch (e) {
      // Fallback to sample data
      return [
        {'day': 'Mon', 'count': 5},
        {'day': 'Tue', 'count': 7},
        {'day': 'Wed', 'count': 6},
        {'day': 'Thu', 'count': 8},
        {'day': 'Fri', 'count': 4},
        {'day': 'Sat', 'count': 9},
        {'day': 'Sun', 'count': 3},
      ];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMemberProgressParticipation(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/member/progress-participation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['progressParticipation']);
      } else {
        throw Exception('Failed to load member progress/participation');
      }
    } catch (e) {
      // Fallback to sample data
      return [
        {'day': 'Mon', 'count': 1},
        {'day': 'Tue', 'count': 2},
        {'day': 'Wed', 'count': 3},
        {'day': 'Thu', 'count': 2},
        {'day': 'Fri', 'count': 4},
        {'day': 'Sat', 'count': 5},
        {'day': 'Sun', 'count': 2},
      ];
    }
  }
} 