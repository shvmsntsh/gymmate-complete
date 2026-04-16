import 'dart:convert';

import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class MessagingService {
  static Future<List<Map<String, dynamic>>> fetchConversations(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/conversations'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(response, 'Failed to load conversations');
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
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messages/conversations'),
      headers: _headers(token),
      body: json.encode({
        'type': type,
        if (trainerId != null) 'trainerId': trainerId,
        if (memberId != null) 'memberId': memberId,
      }),
    );
    return _decodeResponse(response, 'Failed to create conversation');
  }

  static Future<Map<String, dynamic>> fetchConversationMessages(
    String token,
    String conversationId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/messages/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
    );
    return _decodeResponse(response, 'Failed to load messages');
  }

  static Future<Map<String, dynamic>> sendMessage(
    String token,
    String conversationId,
    String body,
  ) async {
    final response = await http.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/messages/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
      body: json.encode({'body': body}),
    );
    return _decodeResponse(response, 'Failed to send message');
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
