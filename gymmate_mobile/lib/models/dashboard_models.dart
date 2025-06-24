class RegistrationStat {
  final String day;
  final int count;

  RegistrationStat({required this.day, required this.count});

  factory RegistrationStat.fromJson(Map<String, dynamic> json) {
    return RegistrationStat(
      day: json['day'],
      count: json['count'],
    );
  }
} 