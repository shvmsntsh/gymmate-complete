import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://shivams-mac-mini-m1.local:5050';
  // Make sure your iPhone is connected to the same Wi-Fi network as the Mac running the backend server.
  // Ensure Info.plist has NSAppTransportSecurity settings to allow arbitrary loads (for non-HTTPS calls).

  static Future<Map<String, dynamic>?> generateInviteCode({
    required String token,
    required String role,
    required String gymName,
  }) async {
    final url = Uri.parse('$baseUrl/api/invite/generate');

    print('🌐 Calling: $url');
    print('📤 Payload: ${jsonEncode({'role': role, 'gymName': gymName})}');
    print('🧾 Headers: Authorization: Bearer $token');

    try {
      print('🛰️ Sending POST request to generate invite code...');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'role': role,
          'gymName': gymName,
        }),
      );
      print('✅ Received response from invite code API.');

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Raw Body: ${response.body}');
      print('📬 Full Response Headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          print('🔍 Decoded Response: $data');

          if (data.containsKey('code')) {
            print('✅ Invite code generated: ${data['code']}');
            return data;
          } else {
            print('⚠️ Response missing "code" key: $data');
            return null;
          }
        } catch (e) {
          print('🚨 Error decoding JSON: $e');
          return null;
        }
      } else {
        print('❌ Server responded with error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('🚨 Exception during HTTP request: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchInviteCodes() async {
    final token = await getToken();
    final gymId = await getGymId();

    final url = Uri.parse('$baseUrl/api/invite/list');
    print('🌐 Fetching invite codes from: $url');
    print('🧾 Headers: Authorization: Bearer $token');

    try {
      print('🛰️ Sending GET request to fetch invite codes...');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print('✅ Received response from invite code list API.');

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Raw Body: ${response.body}');
      print('📬 Full Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('📦 Parsed invite code list: $data');

        return data.map<Map<String, dynamic>>((item) => item as Map<String, dynamic>).toList();
      } else {
        print('❌ Failed to fetch invite codes: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('🚨 Exception during invite code fetch: $e');
      return [];
    }
  }

  static String? _token;
  static String? _role;
  static String? _gymName;
  static String? _gymId;

  static void setLoginData({required String token, required String role, required String gymName, required String gymId}) async {
    _token = token;
    _role = role;
    _gymName = gymName;
    _gymId = gymId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setString('gymName', gymName);
    await prefs.setString('gymId', gymId);
  }

  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String?> getRole() async {
    if (_role != null) return _role;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<String?> getGymName() async {
    if (_gymName != null) return _gymName;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gymName');
  }

  static Future<String?> getGymId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gymId');
  }
}