import 'package:gymmate_mobile/api/api_client.dart';

class CoachingService {
  static Future<Map<String, dynamic>> fetchTrainerDashboard(String token) async {
    final response = await ApiClient.get('/api/trainer/dashboard', token: token);
    return ApiClient.decode(response, 'Failed to load trainer dashboard');
  }

  static Future<List<Map<String, dynamic>>> fetchTrainerClients(String token) async {
    final response = await ApiClient.get('/api/trainer/clients', token: token);
    final payload = ApiClient.decode(response, 'Failed to load clients');
    final clients = payload['clients'] as List<dynamic>? ?? const [];
    return clients
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchTrainerClientSummary(
    String token,
    String memberId,
  ) async {
    final response = await ApiClient.get(
      '/api/trainer/clients/$memberId/summary',
      token: token,
    );
    return ApiClient.decode(response, 'Failed to load client summary');
  }

  static Future<Map<String, dynamic>> fetchOwnerAssignments(String token) async {
    final response = await ApiClient.get('/api/owner/assignments', token: token);
    return ApiClient.decode(response, 'Failed to load owner assignments');
  }

  static Future<Map<String, dynamic>> updateMemberAssignment(
    String token, {
    required String memberId,
    String? trainerId,
    String notes = '',
  }) async {
    final path = '/api/owner/members/$memberId/assignment';
    final response = trainerId == null
        ? await ApiClient.delete(path, token: token)
        : await ApiClient.put(
            path,
            token: token,
            body: {'trainerId': trainerId, 'notes': notes},
          );
    return ApiClient.decode(response, 'Failed to update assignment');
  }
}
