import 'package:flutter_test/flutter_test.dart';
import 'package:gymmate_mobile/utils/auth_input.dart';

void main() {
  group('canonicalIndianPhone', () {
    test('accepts supported Indian phone formats', () {
      expect(canonicalIndianPhone('9876543210'), '+919876543210');
      expect(canonicalIndianPhone('919876543210'), '+919876543210');
      expect(canonicalIndianPhone('+919876543210'), '+919876543210');
    });

    test('rejects partial, landline, and non-phone input', () {
      expect(canonicalIndianPhone('987654321'), isNull);
      expect(canonicalIndianPhone('5123456789'), isNull);
      expect(canonicalIndianPhone('member@example.com'), isNull);
    });
  });

  group('email validation', () {
    test('accepts only valid email shapes', () {
      expect(isValidEmail('member@example.com'), isTrue);
      expect(isValidEmail('member'), isFalse);
      expect(isValidEmail('9876543210'), isFalse);
    });
  });
}
