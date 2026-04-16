import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    if (kIsWeb) {
      final base = Uri.base;
      final isLocalDevHost =
          base.host == 'localhost' || base.host == '127.0.0.1';
      if (isLocalDevHost && base.port != 5050) {
        return 'http://127.0.0.1:5050';
      }
      final isDefaultPort =
          (base.scheme == 'https' && base.port == 443) ||
          (base.scheme == 'http' && base.port == 80);
      if (base.host.isNotEmpty &&
          (base.scheme == 'http' || base.scheme == 'https')) {
        return isDefaultPort
            ? '${base.scheme}://${base.host}'
            : '${base.scheme}://${base.host}:${base.port}';
      }
      return 'https://gymmate-backend.vercel.app';
    }

    if (kDebugMode) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return 'http://10.0.2.2:5050';
        case TargetPlatform.iOS:
          return 'http://localhost:5050';
        default:
          return 'https://gymmate-backend.vercel.app';
      }
    }

    return 'https://gymmate-backend.vercel.app';
  }

  static String get loginUrl => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
  static String get membersUrl => '$baseUrl/api/members';
}
