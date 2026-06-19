import 'package:gymmate_mobile/api/api_client.dart';

class MemberPlanService {
  static Future<bool> hasProfile(String token) async {
    final res = await ApiClient.get('/api/member/me/profile', token: token);
    return res.statusCode == 200;
  }

  static Future<Map<String, dynamic>> saveProfile(
    String token,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiClient.post(
      '/api/member/me/profile',
      token: token,
      body: data,
    );
    return ApiClient.decode(res, 'Failed to save profile');
  }

  static Future<Map<String, dynamic>?> getProfile(String token) async {
    final res = await ApiClient.get('/api/member/me/profile', token: token);
    if (res.statusCode == 404) return null;
    final decoded = ApiClient.decode(res, 'Failed to load profile');
    return decoded['profile'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getWorkoutPlan(String token) async {
    final res = await ApiClient.get(
      '/api/member/me/workout-plan',
      token: token,
    );
    if (res.statusCode == 404) return null;
    final decoded = ApiClient.decode(res, 'Failed to load workout plan');
    return decoded['workoutPlan'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> getMealPlan(String token) async {
    final res = await ApiClient.get('/api/member/me/meal-plan', token: token);
    if (res.statusCode == 404) return null;
    final decoded = ApiClient.decode(res, 'Failed to load meal plan');
    return decoded['mealPlan'] as Map<String, dynamic>?;
  }
}
