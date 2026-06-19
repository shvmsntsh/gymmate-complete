import 'package:gymmate_mobile/api/api_client.dart';

class MemberMembershipService {
  static Future<Map<String, dynamic>?> getMyMembership(String token) async {
    final response = await ApiClient.get(
      '/api/member/me/membership',
      token: token,
    );
    final payload = ApiClient.decode(response, 'Failed to load membership');
    return payload['membership'];
  }

  static Future<Map<String, dynamic>?> getMyReceipt(String token) async {
    final response = await ApiClient.get(
      '/api/member/me/membership/receipt',
      token: token,
    );
    if (response.statusCode == 404) {
      return null;
    }
    final payload = ApiClient.decode(response, 'Failed to load receipt');
    return payload['receipt'];
  }

  static Future<Map<String, dynamic>> getMembershipOptions(String token) async {
    final response = await ApiClient.get(
      '/api/member/me/membership-options',
      token: token,
    );
    return ApiClient.decode(response, 'Failed to load membership options');
  }

  static Future<List<Map<String, dynamic>>> getMyMembershipRequests(
    String token, {
    String? status,
    int limit = 50,
  }) async {
    var path = '/api/member/me/membership-requests?limit=$limit';
    if (status != null) path += '&status=$status';

    final response = await ApiClient.get(path, token: token);
    final payload = ApiClient.decode(response, 'Failed to load requests');
    return (payload['requests'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createMembershipRequest(
    String token, {
    required String requestType,
    String? targetMembershipTemplateId,
    Map<String, bool>? requestedAddOns,
    String? paymentMode,
    String? paymentProofUrl,
    String? memberNote,
  }) async {
    final response = await ApiClient.post(
      '/api/member/me/membership-requests',
      token: token,
      body: {
        'requestType': requestType,
        if (targetMembershipTemplateId != null)
          'targetMembershipTemplateId': targetMembershipTemplateId,
        if (requestedAddOns != null) 'requestedAddOns': requestedAddOns,
        if (paymentMode != null) 'paymentMode': paymentMode,
        if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
        if (memberNote != null) 'memberNote': memberNote,
      },
    );
    return ApiClient.decode(response, 'Failed to submit request');
  }

  static Future<Map<String, dynamic>?> getMyEntitlements(String token) async {
    final response = await ApiClient.get(
      '/api/member/me/entitlements',
      token: token,
    );
    final payload = ApiClient.decode(response, 'Failed to load entitlements');
    return payload['entitlements'];
  }
}
