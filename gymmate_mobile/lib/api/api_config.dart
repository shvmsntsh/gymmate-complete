import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator uses special localhost alias
      return 'http://10.0.2.2:5050';
    } else if (Platform.isIOS || Platform.isMacOS) {
      // Use your Mac’s Bonjour hostname for local network access
      return 'http://Shivams-Mac-mini-M1.local:5050';
    } else {
      // Fallback for web, Windows, Linux, or if above cases don’t match
      return 'http://192.168.1.25:5050';
    }
  }

  static String get loginUrl    => '$baseUrl/api/gym/login';
  static String get registerUrl => '$baseUrl/api/gym//register';
  static String get membersUrl  => '$baseUrl/api/members';
}
