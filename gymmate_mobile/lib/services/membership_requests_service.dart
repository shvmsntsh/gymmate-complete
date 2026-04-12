import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class MembershipRequestsService {
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

  static Future<List<Map<String, dynamic>>> listRequests(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/membership-requests'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(
      response,
      'Failed to load membership requests',
    );
    return (payload['requests'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> getRequest(
    String token,
    String requestId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/owner/membership-requests/$requestId',
      ),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load request details');
  }

  static Future<void> updateRequest(
    String token, {
    required String requestId,
    required String status,
    String response = '',
  }) async {
    final httpResponse = await http.patch(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/owner/membership-requests/$requestId',
      ),
      headers: _headers(token),
      body: json.encode({'status': status, 'response': response}),
    );
    _decodeResponse(httpResponse, 'Failed to update request');
  }

  static Future<void> approveRequest(
    String token,
    String requestId, {
    String response = '',
  }) async {
    await updateRequest(
      token,
      requestId: requestId,
      status: 'approved',
      response: response,
    );
  }

  static Future<void> rejectRequest(
    String token,
    String requestId, {
    String response = '',
  }) async {
    await updateRequest(
      token,
      requestId: requestId,
      status: 'rejected',
      response: response,
    );
  }
}
