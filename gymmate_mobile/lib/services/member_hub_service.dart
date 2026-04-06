import 'dart:convert';
import 'dart:typed_data';

import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class MemberHubService {
  static Future<Map<String, dynamic>> fetchMembershipSummary(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/membership'),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load membership summary');
  }

  static Future<List<Map<String, dynamic>>> fetchAnnouncements(
    String token, {
    int limit = 10,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/announcements?limit=$limit'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response, 'Failed to load announcements');
    final deliveries = payload['deliveries'] as List<dynamic>? ?? const [];
    return deliveries
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<void> markAnnouncementRead(String token, String deliveryId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/member/announcements/$deliveryId/read'),
      headers: _headers(token),
    );
    _decodeResponse(response, 'Failed to mark announcement as read');
  }

  static Future<Map<String, dynamic>> createMembershipRequest(
    String token, {
    required String requestType,
    String? targetPlanId,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/member/membership-requests'),
      headers: _headers(token),
      body: json.encode({
        'requestType': requestType,
        if (targetPlanId != null && targetPlanId.isNotEmpty) 'targetPlanId': targetPlanId,
        if (note != null) 'note': note,
      }),
    );
    return _decodeResponse(response, 'Failed to submit request');
  }

  static Future<Uint8List?> fetchAssetBytes(String token, String? relativeUrl) async {
    if (relativeUrl == null || relativeUrl.trim().isEmpty) return null;
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${relativeUrl.trim()}'),
      headers: _headers(token),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    return null;
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
