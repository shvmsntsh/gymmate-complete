import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:http/http.dart' as http;

class MembershipPlansService {
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

  static Future<List<Map<String, dynamic>>> listPlans(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/membership-plans'),
      headers: _headers(token),
    );
    final payload = _decodeResponse(
      response,
      'Failed to load membership plans',
    );
    return (payload['plans'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> createPlan(
    String token, {
    required String name,
    required int durationDays,
    required double price,
    String description = '',
    List<String> includedServices = const [],
    int renewalLeadDays = 7,
    Map<String, bool> addOns = const {},
    bool active = true,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/membership-plans'),
      headers: _headers(token),
      body: json.encode({
        'name': name,
        'durationDays': durationDays,
        'price': price,
        'description': description,
        'includedServices': includedServices,
        'renewalLeadDays': renewalLeadDays,
        'addOns': addOns,
        'active': active,
      }),
    );
    return _decodeResponse(response, 'Failed to create plan');
  }

  static Future<Map<String, dynamic>> updatePlan(
    String token, {
    required String planId,
    required String name,
    required int durationDays,
    required double price,
    String description = '',
    List<String> includedServices = const [],
    int renewalLeadDays = 7,
    Map<String, bool> addOns = const {},
    bool active = true,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/owner/membership-plans/$planId'),
      headers: _headers(token),
      body: json.encode({
        'name': name,
        'durationDays': durationDays,
        'price': price,
        'description': description,
        'includedServices': includedServices,
        'renewalLeadDays': renewalLeadDays,
        'addOns': addOns,
        'active': active,
      }),
    );
    return _decodeResponse(response, 'Failed to update plan');
  }

  static Future<Map<String, dynamic>> deletePlan(
    String token,
    Map<String, dynamic> plan,
  ) async {
    return updatePlan(
      token,
      planId: plan['id'].toString(),
      name: plan['name']?.toString() ?? 'Archived plan',
      durationDays: (plan['durationDays'] as num?)?.toInt() ?? 1,
      price: (plan['price'] as num?)?.toDouble() ?? 0,
      description: plan['description']?.toString() ?? '',
      includedServices: List<String>.from(plan['includedServices'] ?? const []),
      renewalLeadDays: (plan['renewalLeadDays'] as num?)?.toInt() ?? 7,
      addOns: Map<String, bool>.from(plan['addOns'] ?? const {}),
      active: false,
    );
  }
}
