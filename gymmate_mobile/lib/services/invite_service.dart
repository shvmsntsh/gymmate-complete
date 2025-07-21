import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/models/invite_code_model.dart';
import 'dart:developer' as developer;

class InviteService {
  Future<List<InviteCode>> fetchInviteCodes(String token) async {
    developer.log('Fetching invite codes with token.', name: 'InviteService');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/invite/list'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> codeList = data['codes'];
      developer.log('Successfully fetched ${codeList.length} invite codes.', name: 'InviteService');
      return codeList.map((json) => InviteCode.fromJson(json)).toList();
    } else {
      developer.log('Failed to fetch invite codes: ${response.body}', name: 'InviteService');
      throw Exception('Failed to fetch invite codes.');
    }
  }

  Future<InviteCode> generateInviteCode({
    required String role,
    String? name,
    String? email,
    String? phoneNumber,
    required String token,
  }) async {
    developer.log('Generating invite code for role: $role', name: 'InviteService');

    final Map<String, dynamic> body = {
      'role': role,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
    };

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/invite/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      developer.log('Successfully generated invite code: ${data['code']}', name: 'InviteService');
      return InviteCode.fromJson(data);
    } else {
      final errorBody = jsonDecode(response.body);
      developer.log('Failed to generate invite code: ${response.statusCode} ${response.body}', name: 'InviteService');
      throw Exception('Failed to generate code: ${errorBody['message']}');
    }
  }
} 