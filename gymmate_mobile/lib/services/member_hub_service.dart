import 'dart:typed_data';

import 'package:gymmate_mobile/api/api_client.dart';

class MemberHubService {
  static Future<Map<String, dynamic>> fetchMembershipSummary(String token) async {
    final response = await ApiClient.get('/api/member/membership', token: token);
    return ApiClient.decode(response, 'Failed to load membership summary');
  }

  static Future<List<Map<String, dynamic>>> fetchAnnouncements(
    String token, {
    int limit = 10,
  }) async {
    final response = await ApiClient.get(
      '/api/member/announcements?limit=$limit',
      token: token,
    );
    final payload = ApiClient.decode(response, 'Failed to load announcements');
    final deliveries = payload['deliveries'] as List<dynamic>? ?? const [];
    return deliveries
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<void> markAnnouncementRead(String token, String deliveryId) async {
    final response = await ApiClient.post(
      '/api/member/announcements/$deliveryId/read',
      token: token,
    );
    ApiClient.decode(response, 'Failed to mark announcement as read');
  }

  static Future<Map<String, dynamic>> createMembershipRequest(
    String token, {
    required String requestType,
    String? targetPlanId,
    String? note,
  }) async {
    final response = await ApiClient.post(
      '/api/member/membership-requests',
      token: token,
      body: {
        'requestType': requestType,
        if (targetPlanId != null && targetPlanId.isNotEmpty)
          'targetPlanId': targetPlanId,
        if (note != null) 'note': note,
      },
    );
    return ApiClient.decode(response, 'Failed to submit request');
  }

  static Future<Uint8List?> fetchAssetBytes(String token, String? relativeUrl) async {
    if (relativeUrl == null || relativeUrl.trim().isEmpty) return null;
    final response = await ApiClient.get(relativeUrl.trim(), token: token);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    return null;
  }
}
