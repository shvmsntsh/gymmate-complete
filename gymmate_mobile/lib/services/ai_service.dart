import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';

class AIService {
  static Future<String> sendMessage({required String message, required String token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/ai/chat');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': message}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['reply'] ?? '';
    } else {
      throw Exception('Failed to get AI response');
    }
  }
} 