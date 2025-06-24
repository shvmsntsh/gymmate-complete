class InviteCode {
  final String id;
  final String code;
  final String role;
  final bool used;
  final String? usedBy;
  final DateTime createdAt;

  InviteCode({
    required this.id,
    required this.code,
    required this.role,
    required this.used,
    this.usedBy,
    required this.createdAt,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      id: json['_id'],
      code: json['code'],
      role: json['role'],
      used: json['used'],
      usedBy: json['usedBy'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
} 