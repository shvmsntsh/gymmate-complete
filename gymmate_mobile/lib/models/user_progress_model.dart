class UserProgress {
  final int totalXP;
  final int level;
  final List<Badge> badges;
  final bool isOnboardingComplete;
  final int onboardingProgress;

  UserProgress({
    required this.totalXP,
    required this.level,
    required this.badges,
    required this.isOnboardingComplete,
    required this.onboardingProgress,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    var badgeList = json['badges'] as List;
    List<Badge> badges = badgeList.map((i) => Badge.fromJson(i)).toList();
    
    return UserProgress(
      totalXP: json['totalXP'] ?? 0,
      level: json['level'] ?? 1,
      badges: badges,
      isOnboardingComplete: json['isOnboardingComplete'] ?? false,
      onboardingProgress: json['onboardingProgress'] ?? 0,
    );
  }
}

class Badge {
  final String id;
  final String name;
  final String description;
  final String category;
  final String iconUrl;
  final DateTime unlockedAt;

  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.iconUrl,
    required this.unlockedAt,
  });

  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      iconUrl: json['iconUrl'],
      unlockedAt: DateTime.parse(json['unlockedAt']),
    );
  }
} 