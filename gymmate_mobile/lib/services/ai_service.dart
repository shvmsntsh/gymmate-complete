class AIService {
  // Coach chat is intentionally paused for now.
  // The previous network implementation remains commented out so it can be
  // restored later without changing the surrounding UI contract.
  static Future<String> sendMessage({
    required String message,
    required String token,
  }) async {
    // final url = Uri.parse('${ApiConfig.baseUrl}/api/ai/chat');
    // final response = await http.post(
    //   url,
    //   headers: {
    //     'Authorization': 'Bearer $token',
    //     'Content-Type': 'application/json',
    //   },
    //   body: jsonEncode({'message': message}),
    // );
    // if (response.statusCode == 200) {
    //   final data = json.decode(response.body);
    //   return data['reply'] ?? '';
    // } else {
    //   throw Exception('Failed to get AI response');
    // }
    return 'Coach chat is taking a short breather while we sharpen the experience.';
  }
}
