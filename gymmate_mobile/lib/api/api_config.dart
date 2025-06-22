import 'dart:io';

class ApiConfig {
  static const baseUrl = 'http://shivams-mac-mini-m1.local:5050';

  static String get loginUrl    => '$baseUrl/api/gym/login';
  static String get registerUrl => '$baseUrl/api/gym/register';
  static String get membersUrl  => '$baseUrl/api/members';
}
