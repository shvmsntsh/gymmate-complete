import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/services/member_hub_service.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';

class GymMemberDashboardPage extends StatefulWidget {
  const GymMemberDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymMemberDashboardPage> createState() => _GymMemberDashboardPageState();
}

class _GymMemberDashboardPageState extends State<GymMemberDashboardPage> {
  List<Map<String, dynamic>> progressParticipation = [];
  Map<String, dynamic>? challengeSummary;
  List<Map<String, dynamic>> announcements = const [];
  bool announcementsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    final data = await ApiDashboardService.fetchMemberProgressParticipation(
      token,
    );
    List<Map<String, dynamic>> nextAnnouncements = const [];
    Map<String, dynamic>? nextChallenge;
    try {
      final onboardingService = OnboardingService()..setToken(token);
      final progress = await onboardingService.getUserProgress();
      final challenge = Map<String, dynamic>.from(
        progress['challenge'] ?? progress['firstChallenge'] ?? const {},
      );
      if (challenge.isNotEmpty) {
        nextChallenge = challenge;
      }
    } catch (_) {
      nextChallenge = null;
    }
    try {
      nextAnnouncements = await MemberHubService.fetchAnnouncements(token, limit: 3);
      if (nextAnnouncements.isNotEmpty) {
        nextAnnouncements = await Future.wait(
          nextAnnouncements.map((delivery) async {
            final announcement = Map<String, dynamic>.from(
              delivery['announcement'] ?? const {},
            );
            final imageBytes = await MemberHubService.fetchAssetBytes(
              token,
              announcement['mediaUrl']?.toString(),
            );
            return {
              ...delivery,
              'announcementImageBytes': imageBytes,
            };
          }),
        );
      }
    } catch (_) {
      nextAnnouncements = const [];
    }
    if (!mounted) return;
    setState(() {
      progressParticipation = data;
      challengeSummary = nextChallenge;
      announcements = nextAnnouncements;
      announcementsLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData ?? {};
    final firstName = user['firstName'] ?? authProvider.userName ?? 'Member';
    final gymName = authProvider.gymName ?? 'Your Gym';
    final activeClassesCount = (user['activeClasses'] as num?)?.toInt() ?? 0;
    final attendanceCount = (user['attendance'] as num?)?.toInt() ?? 0;
    final progressCount = (user['progress'] as num?)?.toInt() ?? 0;
    final totalLogs = progressParticipation.fold<int>(
      0,
      (sum, entry) => sum + ((entry['count'] as num?)?.toInt() ?? 0),
    );
    final chartPoints = progressParticipation
        .map(
          (entry) => DashboardBarPoint(
            label: (entry['day'] ?? '').toString(),
            value: ((entry['count'] as num?)?.toInt() ?? 0),
          ),
        )
        .toList();
    final bestPoint = chartPoints.isEmpty
        ? null
        : chartPoints.reduce((a, b) => a.value >= b.value ? a : b);
    final consistency = _normalizedPercent(progressParticipation);
    final consistencyPercent = (consistency * 100).round();
    final consistencyCaption = totalLogs == 0
        ? 'Start with today’s plan'
        : '$totalLogs weekly logs';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 16),
                DashboardHeroCard(
                  eyebrow: 'Plan',
                  title: 'Your plan is ready.',
                  subtitle:
                      'Open today’s workout, meals, and check-ins in one place with $gymName.',
                  metaLeft: '$activeClassesCount classes',
                  metaRight: '$totalLogs logs',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(1),
                  buttonLabel: 'Open plan',
                  illustration: Image.asset(
                    'assets/images/member_illustration.png',
                    height: 176,
                    fit: BoxFit.contain,
                  ),
                ),
                if (challengeSummary != null &&
                    challengeSummary!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ChallengeStrip(challenge: challengeSummary!),
                ],
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Announcements',
                  title: announcements.isEmpty
                      ? 'No fresh updates right now.'
                      : 'Latest from your gym.',
                  subtitle: announcementsLoading
                      ? 'Loading latest notices.'
                      : 'Offers, holiday notes, and service updates land here.',
                  child: announcementsLoading
                      ? const Center(child: CircularProgressIndicator())
                      : announcements.isEmpty
                          ? Text(
                              'When your gym sends announcements, they will appear here.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          : Column(
                              children: List.generate(announcements.length, (index) {
                                final delivery = announcements[index];
                                final announcement = Map<String, dynamic>.from(
                                  delivery['announcement'] ?? {},
                                );
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == announcements.length - 1 ? 0 : 12,
                                  ),
                                  child: _AnnouncementCard(
                                    delivery: delivery,
                                    announcement: announcement,
                                  ),
                                );
                              }),
                            ),
                ),
                const SizedBox(height: 18),
                Column(
                  children: [
                    _ConsistencyPanel(
                      progress: consistency,
                      value: '$consistencyPercent%',
                      label: 'Consistency',
                      caption: consistencyCaption,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DashboardStatPanel(
                            label: 'Attendance',
                            value: '$attendanceCount',
                            caption: 'sessions kept',
                            icon: Icons.local_fire_department_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardStatPanel(
                            label: 'Momentum',
                            value: '$progressCount',
                            caption: 'current streak',
                            icon: Icons.schedule_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Weekly Rhythm',
                  title: 'Your week at a glance.',
                  subtitle: 'See where your rhythm is building.',
                  trailing: Text(
                    'LAST 7 DAYS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  child: DashboardBarChartCard(
                    points: chartPoints,
                    summaryLeft: '$totalLogs weekly logs',
                    summaryRight: bestPoint == null
                        ? null
                        : 'Best day: ${bestPoint.label}',
                    emptyTitle: 'No activity yet',
                    emptySubtitle:
                        'As you log sessions and check in, your weekly rhythm will appear here.',
                    detailBuilder: (label, value) =>
                        '$label logged $value session${value == 1 ? '' : 's'}.',
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Upcoming Focus',
                  title: 'Next checkpoints.',
                  trailing: TextButton(
                    onPressed: () => MainNavigationScaffold.switchTab(1),
                    child: const Text('View all'),
                  ),
                  child: Column(children: _buildCheckpointCards(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCheckpointCards(BuildContext context) {
    final entries = progressParticipation.take(2).toList();
    if (entries.isEmpty) {
      return [
        DashboardListTileCard(
          title: 'Your first checkpoint is waiting',
          subtitle: 'Complete today’s plan to start the streak.',
          trailingTop: 'Today',
          trailingBottom: 'Start strong',
          leading: _avatarBadge(context, Icons.fitness_center_rounded),
          onTap: () => MainNavigationScaffold.switchTab(1),
        ),
      ];
    }

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final day = (entry['day'] ?? 'Today').toString();
      final count = ((entry['count'] as num?)?.toInt() ?? 0);
      return Padding(
        padding: EdgeInsets.only(bottom: index == entries.length - 1 ? 0 : 12),
        child: DashboardListTileCard(
          title: _memberCheckpointTitle(index),
          subtitle: '$day focus • Keep your pace steady.',
          trailingTop: '$count logs',
          trailingBottom: day.toUpperCase(),
          leading: _avatarBadge(context, Icons.calendar_today_rounded),
          onTap: () => MainNavigationScaffold.switchTab(3),
        ),
      );
    });
  }

  String _memberCheckpointTitle(int index) {
    switch (index) {
      case 0:
        return 'Today\'s movement check-in';
      case 1:
        return 'Recovery and reset';
      default:
        return 'Keep the streak alive';
    }
  }

  double _normalizedPercent(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return 0.0;
    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + ((entry['count'] as num?)?.toInt() ?? 0),
    );
    return (total / (entries.length * 5)).clamp(0.0, 1.0);
  }

  Widget _avatarBadge(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: theme.colorScheme.primary),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final Map<String, dynamic> announcement;

  const _AnnouncementCard({
    required this.delivery,
    required this.announcement,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = delivery['announcementImageBytes'];
    final imageBytes = bytes is Uint8List ? bytes : null;
    final theme = Theme.of(context);

    return DashboardListTileCard(
      title: (announcement['title'] ?? 'Announcement').toString(),
      subtitle: (announcement['body'] ?? '').toString(),
      trailingTop: (announcement['type'] ?? 'general').toString().toUpperCase(),
      trailingBottom: delivery['inAppStatus'] == 'read' ? 'READ' : 'NEW',
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.campaign_outlined,
          color: theme.colorScheme.primary,
        ),
      ),
      details: imageBytes == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.memory(
                imageBytes,
                height: 148,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class _ChallengeStrip extends StatelessWidget {
  final Map<String, dynamic> challenge;

  const _ChallengeStrip({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ((challenge['progress'] as num?)?.toInt() ?? 0).clamp(
      0,
      100,
    );
    final summary = (challenge['summary'] ?? '').toString().trim();
    final nextStep = (challenge['nextStep'] ?? '').toString().trim();
    final current = challenge['current'];
    final target = challenge['target'];
    final metric = current != null && target != null
        ? '$current/$target'
        : null;

    return EditorialSurface(
      padding: const EdgeInsets.all(14),
      radius: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.flag_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _challengeLabel(challenge['type']),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  summary.isNotEmpty ? summary : 'Keep the challenge moving.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (nextStep.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    nextStep,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$progress%', style: theme.textTheme.titleMedium),
              if (metric != null)
                Text(metric, style: theme.textTheme.labelMedium),
            ],
          ),
        ],
      ),
    );
  }

  String _challengeLabel(dynamic type) {
    switch ((type ?? '').toString()) {
      case 'first_workout':
        return 'First Workout';
      case 'meal_rhythm':
        return 'Meal Rhythm';
      case '7_day_checkin':
      default:
        return '7-Day Check-in';
    }
  }
}

class _ConsistencyPanel extends StatelessWidget {
  final double progress;
  final String value;
  final String label;
  final String caption;

  const _ConsistencyPanel({
    required this.progress,
    required this.value,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorialSurface(
      padding: const EdgeInsets.all(16),
      radius: 24,
      child: Row(
        children: [
          EditorialProgressRing(
            progress: progress,
            value: value,
            label: label,
            sublabel: caption,
            size: 104,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show up today and the week gets easier.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'One session keeps the streak moving.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
