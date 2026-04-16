import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class MemberMembershipService {
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

  static Future<Map<String, dynamic>?> getMyMembership(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/me/membership'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response, 'Failed to load membership');
    return payload['membership'];
  }

  static Future<Map<String, dynamic>?> getMyReceipt(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/me/membership/receipt'),
      headers: _headers(token),
    );
    if (response.statusCode == 404) {
      return null;
    }
    final payload = _decodeResponse(response, 'Failed to load receipt');
    return payload['receipt'];
  }

  static Future<Map<String, dynamic>> getMembershipOptions(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/me/membership-options'),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load membership options');
  }

  static Future<List<Map<String, dynamic>>> getMyMembershipRequests(
    String token, {
    String? status,
    int limit = 50,
  }) async {
    var url =
        '${ApiConfig.baseUrl}/api/member/me/membership-requests?limit=$limit';
    if (status != null) url += '&status=$status';

    final response = await http.get(Uri.parse(url), headers: _headers(token));
    final payload = _decodeResponse(response, 'Failed to load requests');
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
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/member/me/membership-requests'),
      headers: _headers(token),
      body: json.encode({
        'requestType': requestType,
        if (targetMembershipTemplateId != null)
          'targetMembershipTemplateId': targetMembershipTemplateId,
        if (requestedAddOns != null) 'requestedAddOns': requestedAddOns,
        if (paymentMode != null) 'paymentMode': paymentMode,
        if (paymentProofUrl != null) 'paymentProofUrl': paymentProofUrl,
        if (memberNote != null) 'memberNote': memberNote,
      }),
    );
    return _decodeResponse(response, 'Failed to submit request');
  }

  static Future<Map<String, dynamic>?> getMyEntitlements(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/member/me/entitlements'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response, 'Failed to load entitlements');
    return payload['entitlements'];
  }
}
