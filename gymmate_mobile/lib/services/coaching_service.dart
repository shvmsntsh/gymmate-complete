import 'dart:convert';

import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class CoachingService {
  static Future<Map<String, dynamic>> fetchTrainerDashboard(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/trainer/dashboard'),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load trainer dashboard');
  }

  static Future<List<Map<String, dynamic>>> fetchTrainerClients(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/trainer/clients'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response, 'Failed to load clients');
    final clients = payload['clients'] as List<dynamic>? ?? const [];
    return clients
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> fetchTrainerClientSummary(
    String token,
    String memberId,
  ) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/trainer/clients/$memberId/summary'),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load client summary');
  }

  static Future<Map<String, dynamic>> fetchOwnerAssignments(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/assignments'),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load owner assignments');
  }

  static Future<Map<String, dynamic>> updateMemberAssignment(
    String token, {
    required String memberId,
    String? trainerId,
    String notes = '',
  }) async {
    final endpoint = Uri.parse(
      '${ApiConfig.baseUrl}/api/owner/members/$memberId/assignment',
    );
    final response = trainerId == null
        ? await http.delete(endpoint, headers: _headers(token))
        : await http.put(
            endpoint,
            headers: _headers(token),
            body: json.encode({'trainerId': trainerId, 'notes': notes}),
          );
    return _decodeResponse(response, 'Failed to update assignment');
  }

  static Map<String, String> _headers(String token) {
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Map<String, dynamic> _decodeResponse(
    http.Response response,
    String fallbackMessage,
  ) {
    final payload = json.decode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return payload;
    }
    throw Exception(payload['message'] ?? fallbackMessage);
  }
}
