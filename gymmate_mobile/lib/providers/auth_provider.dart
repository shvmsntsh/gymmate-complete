import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/utils/branding_utils.dart';
import 'package:gymmate_mobile/utils/role_utils.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userRole;
  String? _userName;
  String? _userEmail;
  String? _gymName;
  bool? _hasCompletedOnboarding;
  Map<String, dynamic>? _userData;
  String? _avatarPath;
  Map<String, dynamic> _branding = normalizeBranding(null);

  final _storage = const FlutterSecureStorage();

  bool get isAuth => _token != null;

  String? get token => _token;
  String? get userId => _userId;
  String? get userRole => _userRole;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get gymName => _gymName;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding ?? false;
  Map<String, dynamic>? get userData => _userData;
  String? get avatarPath => _avatarPath;
  Map<String, dynamic> get branding => _branding;

  String _resolvedAvatarPath(dynamic candidate, String? role) {
    final value = '${candidate ?? ''}'.trim();
    if (value.isNotEmpty) {
      if (value.startsWith('data:')) {
        return value;
      }
      return value;
    }
    return _defaultAvatarForRole(role);
  }

  Future<bool> login(String email, String password) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to login');
      }

      _token = responseData['token'];
      final user = responseData['user'];
      final normalizedRole =
          user['normalizedRole'] ?? normalizeRole(user['role']);
      _userData = {
        ...user,
        'role': normalizedRole,
        'normalizedRole': normalizedRole,
      };
      _userId = user['id'];
      _userRole = normalizedRole;
      _userName = user['name'];
      _userEmail = user['email'];
      _gymName = user['gymName'];
      _hasCompletedOnboarding = user['hasCompletedOnboarding'] ?? false;
      _avatarPath = _resolvedAvatarPath(user['avatarPath'], _userRole);
      await _loadBrandingForGym(user['gymId']);

      await _storage.write(key: 'user_token', value: _token);
      await _storage.write(key: 'user_data', value: json.encode(_userData));
      await _storage.write(key: 'user_id', value: _userId);
      await _storage.write(key: 'user_role', value: _userRole);
      await _storage.write(key: 'user_name', value: _userName);
      await _storage.write(key: 'user_email', value: _userEmail);
      await _storage.write(key: 'gym_name', value: _gymName);
      await _storage.write(
        key: 'has_completed_onboarding',
        value: _hasCompletedOnboarding.toString(),
      );
      await _storage.write(key: 'avatar_path', value: _avatarPath ?? '');
      await _storage.write(key: 'branding_data', value: json.encode(_branding));

      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> quickLogin(String phoneNumber, String accessCode) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/quick-login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone_number': phoneNumber, 'accessCode': accessCode}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode != 200) {
        throw Exception(responseData['message'] ?? 'Failed to login');
      }

      _token = responseData['token'];
      final user = responseData['user'];
      final normalizedRole =
          user['normalizedRole'] ?? normalizeRole(user['role']);
      _userData = {
        ...user,
        'role': normalizedRole,
        'normalizedRole': normalizedRole,
      };
      _userId = user['id'];
      _userRole = normalizedRole;
      _userName = user['name'];
      _userEmail = user['email'];
      _gymName = user['gymName'];
      _hasCompletedOnboarding = user['hasCompletedOnboarding'] ?? false;
      _avatarPath = _resolvedAvatarPath(user['avatarPath'], _userRole);
      await _loadBrandingForGym(user['gymId']);

      await _storage.write(key: 'user_token', value: _token);
      await _storage.write(key: 'user_data', value: json.encode(_userData));
      await _storage.write(key: 'user_id', value: _userId);
      await _storage.write(key: 'user_role', value: _userRole);
      await _storage.write(key: 'user_name', value: _userName);
      await _storage.write(key: 'user_email', value: _userEmail);
      await _storage.write(key: 'gym_name', value: _gymName);
      await _storage.write(
        key: 'has_completed_onboarding',
        value: _hasCompletedOnboarding.toString(),
      );
      await _storage.write(key: 'avatar_path', value: _avatarPath ?? '');
      await _storage.write(key: 'branding_data', value: json.encode(_branding));

      notifyListeners();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'user_token');
    if (token == null) {
      return false;
    }

    // Reconstruct the user object from stored data
    final userDataStr = await _storage.read(key: 'user_data');
    if (userDataStr != null) {
      final storedUser = json.decode(userDataStr) as Map<String, dynamic>;
      final normalizedRole =
          storedUser['normalizedRole'] ?? normalizeRole(storedUser['role']);
      _userData = {
        ...storedUser,
        'role': normalizedRole,
        'normalizedRole': normalizedRole,
      };
    }

    _token = token;
    _userId = await _storage.read(key: 'user_id');
    _userRole = normalizeRole(await _storage.read(key: 'user_role'));
    _userName = await _storage.read(key: 'user_name');
    _userEmail = await _storage.read(key: 'user_email');
    _gymName = await _storage.read(key: 'gym_name');
    _hasCompletedOnboarding =
        (await _storage.read(key: 'has_completed_onboarding')) == 'true';
    _avatarPath = _resolvedAvatarPath(
      await _storage.read(key: 'avatar_path'),
      _userRole,
    );
    final brandingData = await _storage.read(key: 'branding_data');
    if (brandingData != null) {
      _branding = normalizeBranding(json.decode(brandingData));
    } else {
      await _loadBrandingForGym(_userData?['gymId']);
    }

    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _userRole = null;
    _userName = null;
    _userEmail = null;
    _gymName = null;
    _hasCompletedOnboarding = null;
    _userData = null;
    _avatarPath = null;
    _branding = normalizeBranding(null);
    // Clear secure storage first
    await _storage.deleteAll();
    // Now notify listeners
    notifyListeners();
  }

  Future<bool> register(Map<String, dynamic> registrationData) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/auth/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(registrationData),
      );
      final responseData = json.decode(response.body);

      if (response.statusCode != 201) {
        throw Exception(
          responseData['error'] ??
              responseData['message'] ??
              'Failed to register',
        );
      }

      await applySessionUpdate(responseData);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _storage.write(key: 'has_completed_onboarding', value: 'true');
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    try {
      // We don't have the password, so instead, fetch user profile by token if such endpoint exists
      final profileUrl = Uri.parse('${ApiConfig.baseUrl}/api/auth/me');
      final response = await http.get(
        profileUrl,
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final user = json.decode(response.body);
        final normalizedRole =
            user['normalizedRole'] ?? normalizeRole(user['role']);
        _userData = {
          ...user,
          'role': normalizedRole,
          'normalizedRole': normalizedRole,
        };
        _userId = (user['id'] ?? user['_id'])?.toString();
        _userRole = normalizedRole;
        _userName = user['name'];
        _userEmail = user['email'];
        _gymName = user['gymName'];
        _hasCompletedOnboarding = user['hasCompletedOnboarding'] ?? false;
        _avatarPath = _resolvedAvatarPath(
          user['avatarPath'] ?? await _storage.read(key: 'avatar_path'),
          _userRole,
        );
        await _loadBrandingForGym(user['gymId']);
        await _storage.write(key: 'user_data', value: json.encode(_userData));
        await _storage.write(key: 'user_id', value: _userId);
        await _storage.write(key: 'user_role', value: _userRole);
        await _storage.write(key: 'user_name', value: _userName);
        await _storage.write(key: 'user_email', value: _userEmail);
        await _storage.write(key: 'gym_name', value: _gymName);
        await _storage.write(
          key: 'has_completed_onboarding',
          value: _hasCompletedOnboarding.toString(),
        );
        await _storage.write(key: 'avatar_path', value: _avatarPath ?? '');
        await _storage.write(
          key: 'branding_data',
          value: json.encode(_branding),
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> applySessionUpdate(Map<String, dynamic> responseData) async {
    final nextToken = (responseData['token'] ?? _token)?.toString();
    final rawUser = responseData['user'];
    if (rawUser is! Map) return;

    final user = Map<String, dynamic>.from(rawUser);
    final normalizedRole =
        user['normalizedRole'] ?? normalizeRole(user['role']);

    _token = nextToken;
    _userData = {
      ...(_userData ?? const <String, dynamic>{}),
      ...user,
      'role': normalizedRole,
      'normalizedRole': normalizedRole,
    };
    _userId = (user['id'] ?? _userId)?.toString();
    _userRole = normalizedRole;
    _userName = user['name']?.toString() ?? _userName;
    _userEmail = user['email']?.toString() ?? _userEmail;
    _gymName = user['gymName']?.toString() ?? _gymName;
    _hasCompletedOnboarding =
        user['hasCompletedOnboarding'] ?? _hasCompletedOnboarding ?? false;
    _avatarPath = _resolvedAvatarPath(
      user['avatarPath'] ?? _avatarPath,
      _userRole,
    );
    await _loadBrandingForGym(user['gymId'] ?? _userData?['gymId']);

    if (_token != null) {
      await _storage.write(key: 'user_token', value: _token);
    }
    await _storage.write(key: 'user_data', value: json.encode(_userData));
    await _storage.write(key: 'user_id', value: _userId);
    await _storage.write(key: 'user_role', value: _userRole);
    await _storage.write(key: 'user_name', value: _userName);
    await _storage.write(key: 'user_email', value: _userEmail);
    await _storage.write(key: 'gym_name', value: _gymName);
    await _storage.write(
      key: 'has_completed_onboarding',
      value: (_hasCompletedOnboarding ?? false).toString(),
    );
    await _storage.write(key: 'avatar_path', value: _avatarPath ?? '');
    await _storage.write(key: 'branding_data', value: json.encode(_branding));
    notifyListeners();
  }

  String _defaultAvatarForRole(String? role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return 'assets/logos/superadmin_logo.png';
      case 'owner':
        return 'assets/avatars/o_m_1.png';
      case 'trainer':
        return 'assets/avatars/t_m_1.png';
      case 'member':
        return 'assets/avatars/m_m_1.png';
      default:
        return 'assets/avatars/o_m_1.png';
    }
  }

  Future<void> _loadBrandingForGym(dynamic gymId) async {
    if (gymId == null || gymId.toString().isEmpty) {
      _branding = normalizeBranding({'gymName': _gymName});
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/branding/$gymId'),
      );

      if (response.statusCode == 200) {
        _branding = normalizeBranding(json.decode(response.body));
      } else {
        _branding = normalizeBranding({'gymName': _gymName});
      }
    } catch (_) {
      _branding = normalizeBranding({'gymName': _gymName});
    }
  }

  Future<void> refreshBranding() async {
    await _loadBrandingForGym(_userData?['gymId']);
    _gymName = _branding['gymName']?.toString() ?? _gymName;
    if (_userData != null) {
      _userData = {..._userData!, 'gymName': _gymName};
      await _storage.write(key: 'user_data', value: json.encode(_userData));
    }
    await _storage.write(key: 'gym_name', value: _gymName);
    await _storage.write(key: 'branding_data', value: json.encode(_branding));
    notifyListeners();
  }

  Future<void> setLocalAvatarPath(String path) async {
    _avatarPath = _resolvedAvatarPath(path, _userRole);
    await _storage.write(key: 'avatar_path', value: _avatarPath);
    notifyListeners();
  }

  Future<void> setAvatarPath(String path) async {
    if (_token == null) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/avatar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: json.encode({'avatar': path}),
    );

    final data = json.decode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update avatar');
    }

    _avatarPath = _resolvedAvatarPath(data['avatarPath'] ?? path, _userRole);
    _userData = {
      ...(_userData ?? const <String, dynamic>{}),
      'avatarPath': _avatarPath,
    };
    await _storage.write(key: 'avatar_path', value: _avatarPath);
    await _storage.write(key: 'user_data', value: json.encode(_userData));
    notifyListeners();
  }
}
