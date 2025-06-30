import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5050'; // Android emulator localhost
    } else if (Platform.isIOS) {
      return 'http://localhost:5050'; // iOS simulator localhost
    } else {
      return 'http://localhost:5050'; // Default to localhost for other platforms
    }
  }

  static String get loginUrl    => '$baseUrl/api/auth/login';
  static String get registerUrl => '$baseUrl/api/auth/register';
  static String get membersUrl  => '$baseUrl/api/members';
}
