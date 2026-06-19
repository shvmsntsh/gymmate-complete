import 'package:gymmate_mobile/api/api_client.dart';

class PaymentsService {
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
    final response = await ApiClient.post(
      '/api/owner/payments',
      token: token,
      body: {
        'memberId': memberId,
        if (membershipId != null) 'membershipId': membershipId,
        if (membershipRequestId != null)
          'membershipRequestId': membershipRequestId,
        'amount': amount,
        'mode': mode,
        'reference': reference,
        'note': note,
        'activate': activate,
      },
    );
    return ApiClient.decode(response, 'Failed to record payment');
  }
}
