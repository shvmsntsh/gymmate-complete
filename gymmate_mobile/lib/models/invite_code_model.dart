class InviteCode {
  final String id;
  final String code;
  final String role;
  final bool used;
  final String? usedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? statusLabel;
  final String? createdDateLabel;
  final String? usedDateLabel;
  final InviteUsedByUser? usedByUser;

  InviteCode({
    required this.id,
    required this.code,
    required this.role,
    required this.used,
    this.usedBy,
    required this.createdAt,
    this.updatedAt,
    this.statusLabel,
    this.createdDateLabel,
    this.usedDateLabel,
    this.usedByUser,
  });

  factory InviteCode.fromJson(Map<String, dynamic> json) {
    return InviteCode(
      id: json['_id'],
      code: json['code'],
      role: json['role'],
      used: json['used'],
      usedBy: json['usedBy'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      statusLabel: json['statusLabel'],
      createdDateLabel: json['createdDateLabel'],
      usedDateLabel: json['usedDateLabel'],
      usedByUser: json['usedByUser'] != null
          ? InviteUsedByUser.fromJson(
              Map<String, dynamic>.from(json['usedByUser']),
            )
          : null,
    );
  }
}

class InviteUsedByUser {
  final String? id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? role;
  final DateTime? joinedAt;
  final bool hasCompletedOnboarding;

  InviteUsedByUser({
    this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.role,
    this.joinedAt,
    required this.hasCompletedOnboarding,
  });

  factory InviteUsedByUser.fromJson(Map<String, dynamic> json) {
    return InviteUsedByUser(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phone_number']?.toString(),
      role: json['role']?.toString(),
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'])
          : null,
      hasCompletedOnboarding: json['hasCompletedOnboarding'] == true,
    );
  }
}
