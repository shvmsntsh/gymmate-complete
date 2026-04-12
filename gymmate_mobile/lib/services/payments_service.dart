import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class PaymentsService {
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

  static Future<Map<String, dynamic>> recordPayment(
    String token, {
    required String memberId,
    String? membershipId,
    String? membershipRequestId,
    required double amount,
    required String mode,
    String reference = '',
    String note = '',
    bool activate = false,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/payments'),
      headers: _headers(token),
      body: json.encode({
        'memberId': memberId,
        if (membershipId != null) 'membershipId': membershipId,
        if (membershipRequestId != null)
          'membershipRequestId': membershipRequestId,
        'amount': amount,
        'mode': mode,
        'reference': reference,
        'note': note,
        'activate': activate,
      }),
    );
    return _decodeResponse(response, 'Failed to record payment');
  }
}
