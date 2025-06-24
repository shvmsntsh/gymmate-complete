import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

class DashboardService {
  static Future<Map<String, int>> fetchDashboardStats(String token) async {
    final headers = {'Authorization': 'Bearer $token'};

    // Fetch gyms
    final gymsResp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/gym/members'),
      headers: headers,
    );
    final gymsData = jsonDecode(gymsResp.body);
    final gymsCount = (gymsData['members'] as List? ?? []).length;

    // Fetch users
    final usersResp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/all-members'),
      headers: headers,
    );
    final usersData = jsonDecode(usersResp.body);
    final membersCount = (usersData['members'] as List? ?? []).length;

    // Fetch invites
    final invitesResp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/invite/list'),
      headers: headers,
    );
    final invitesData = jsonDecode(invitesResp.body);
    final invitesCount = (invitesData['codes'] as List? ?? []).length;

    return {
      'gyms': gymsCount,
      'members': membersCount,
      'invites': invitesCount,
    };
  }
} 