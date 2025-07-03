import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api/api_config.dart';

class AiService {
  Future<Map<String, dynamic>> generatePlan({
    required Map<String, dynamic> userData,
    required String? token,
  }) async {
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ai/generate-plan'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(userData),
    );

    if (response.statusCode == 200) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes));
      return decodedBody;
    } else {
      print('❌ AI Service failed. Status Code: ${response.statusCode}');
      print('Raw error from backend: ${response.body}');
      throw Exception('Failed to generate plan: ${response.body}');
    }
  }

  Future<String> coachChat({
    required String message,
    required String? token,
  }) async {
    if (token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/ai/coach-chat'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({ 'message': message }),
    );

    if (response.statusCode == 200) {
      final decodedBody = json.decode(utf8.decode(response.bodyBytes));
      return decodedBody['reply'] as String;
    } else {
      print('❌ AI Coach Chat failed. Status Code: [31m${response.statusCode}[0m');
      print('Raw error from backend: ${response.body}');
      throw Exception('Failed to get AI coach reply: ${response.body}');
    }
  }
} 