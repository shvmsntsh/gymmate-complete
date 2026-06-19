import 'package:gymmate_mobile/api/api_client.dart';

class ApiDashboardService {
  static Future<Map<String, dynamic>> fetchDashboardStats(String token) async {
    final response = await ApiClient.get(
      '/api/auth/dashboard/stats',
      token: token,
    );
    return ApiClient.decode(response, 'Failed to load dashboard stats');
  }

  static Future<List<Map<String, dynamic>>> fetchCategorizedMembers(
    String token,
  ) async {
    final response = await ApiClient.get(
      '/api/auth/members/categorized',
      token: token,
    );
    final data = ApiClient.decode(response, 'Failed to load categorized members');
    final owners = data['gymOwners'] as List<dynamic>? ?? const [];
    return owners
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchGymRegistrationsLast7Days(
    String token,
  ) async {
    final response = await ApiClient.get(
      '/api/gym/registrations/last7days',
      token: token,
    );
    final data = ApiClient.decode(response, 'Failed to load gym registrations');
    return List<Map<String, dynamic>>.from(data['registrations'] as List);
  }

  static Future<List<Map<String, dynamic>>> fetchTrainerAttendanceProgress(
    String token,
  ) async {
    final response = await ApiClient.get(
      '/api/trainer/attendance-progress',
      token: token,
    );
    final data = ApiClient.decode(
      response,
      'Failed to load trainer attendance/progress',
    );
    return List<Map<String, dynamic>>.from(data['attendanceProgress'] as List);
  }

  static Future<List<Map<String, dynamic>>> fetchMemberProgressParticipation(
    String token,
  ) async {
    final response = await ApiClient.get(
      '/api/member/progress-participation',
      token: token,
    );
    final data = ApiClient.decode(
      response,
      'Failed to load member progress/participation',
    );
    return List<Map<String, dynamic>>.from(data['progressParticipation'] as List);
  }
}
