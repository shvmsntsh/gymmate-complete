import 'package:gymmate_mobile/api/api_client.dart';

class MessagingService {
  static Future<List<Map<String, dynamic>>> fetchConversations(String token) async {
    final response = await ApiClient.get(
      '/api/messages/conversations',
      token: token,
    );
    final payload = ApiClient.decode(response, 'Failed to load conversations');
    final conversations = payload['conversations'] as List<dynamic>? ?? const [];
    return conversations
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createConversation(
    String token, {
    required String type,
    String? trainerId,
    String? memberId,
  }) async {
    final response = await ApiClient.post(
      '/api/messages/conversations',
      token: token,
      body: {
        'type': type,
        if (trainerId != null) 'trainerId': trainerId,
        if (memberId != null) 'memberId': memberId,
      },
    );
    return ApiClient.decode(response, 'Failed to create conversation');
  }

  static Future<Map<String, dynamic>> fetchConversationMessages(
    String token,
    String conversationId,
  ) async {
    final response = await ApiClient.get(
      '/api/messages/conversations/$conversationId/messages',
      token: token,
    );
    return ApiClient.decode(response, 'Failed to load messages');
  }

  static Future<Map<String, dynamic>> sendMessage(
    String token,
    String conversationId,
    String body,
  ) async {
    final response = await ApiClient.post(
      '/api/messages/conversations/$conversationId/messages',
      token: token,
      body: {'body': body},
    );
    return ApiClient.decode(response, 'Failed to send message');
  }
}
