import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';

class GymMemberDashboardPage extends StatefulWidget {
  const GymMemberDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymMemberDashboardPage> createState() => _GymMemberDashboardPageState();
}

class _GymMemberDashboardPageState extends State<GymMemberDashboardPage> {
  List<Map<String, dynamic>> progressParticipation = [];

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
    if (!mounted) return;
    setState(() {
      progressParticipation = data;
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
                  eyebrow: 'Today\'s Plan',
                  title: 'Your next session is ready whenever you are.',
                  subtitle:
                      'Follow your workout, stay consistent, and keep your rhythm with $gymName all in one place.',
                  metaLeft: '$activeClassesCount active classes',
                  metaRight: '$totalLogs weekly logs',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(1),
                  buttonLabel: 'Open plan',
                  illustration: Image.asset(
                    'assets/images/member_illustration.png',
                    height: 176,
                    fit: BoxFit.contain,
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
                            caption: 'gym consistency',
                            icon: Icons.local_fire_department_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardStatPanel(
                            label: 'Momentum',
                            value: '$progressCount',
                            caption: 'current rhythm',
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
                  title: 'Your movement across the week.',
                  subtitle:
                      'A simple read on how consistently you showed up and trained.',
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
                  title: 'The next checkpoints to keep moving.',
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
    final entries = progressParticipation.take(3).toList();
    if (entries.isEmpty) {
      return [
        DashboardListTileCard(
          title: 'Your first training checkpoint is waiting',
          subtitle:
              'Complete today\'s plan to start building a steady weekly rhythm.',
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
          subtitle: '$day focus • Keep your pace smooth and consistent.',
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
      padding: const EdgeInsets.all(18),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Show up today and the week gets easier.',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            'Keep your streak moving with one session at a time. Your consistency builds every time you log a workout.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Center(
            child: EditorialProgressRing(
              progress: progress,
              value: value,
              label: label,
              sublabel: caption,
              size: 148,
            ),
          ),
        ],
      ),
    );
  }
}
