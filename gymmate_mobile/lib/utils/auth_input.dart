String? canonicalIndianPhone(String? value) {
  final digits = (value ?? '').toString().replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;

  final national = digits.length == 12 && digits.startsWith('91')
      ? digits.substring(2)
      : digits;
  if (national.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(national)) {
    return null;
  }
  return '+91$national';
}

bool isValidEmail(String? value) {
  return RegExp(r'^\S+@\S+\.\S+$').hasMatch((value ?? '').toString().trim());
}

String? validateEmail(String? value) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return 'Email is required';
  return isValidEmail(text) ? null : 'Enter a valid email';
}

String? validatePhone(String? value) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) return 'Phone number is required';
  return canonicalIndianPhone(text) == null
      ? 'Enter a valid phone number'
      : null;
}

String? validatePassword(String? value) {
  final text = (value ?? '').toString();
  if (text.isEmpty) return 'Password is required';
  return text.length >= 6 ? null : 'Password must be at least 6 characters';
}
