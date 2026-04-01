import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import '../widgets/dashboard_charts.dart';
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
    final activeClasses = '${user['activeClasses'] ?? 0}';
    final attendance = '${user['attendance'] ?? 0}';
    final progress = '${user['progress'] ?? 0}';
    final totalLogs = progressParticipation.fold<int>(
      0,
      (sum, entry) => sum + ((entry['count'] as num?)?.toInt() ?? 0),
    );

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
                  'Welcome back\n$firstName',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: 'Today\'s Workout',
                  title: 'Stay steady and keep your next session simple.',
                  subtitle:
                      '$gymName is ready with your plan, progress, and daily rhythm in one calm view.',
                  metaLeft: '$activeClasses active',
                  metaRight: '$totalLogs logs',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(2),
                  buttonLabel: 'Open plan',
                  illustration: Image.asset(
                    'assets/images/member_illustration.png',
                    height: 176,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _GoalRingCard(
                        progress: _normalizedPercent(progressParticipation),
                        stepsText: '$totalLogs',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          DashboardStatPanel(
                            label: 'Attendance',
                            value: attendance,
                            caption: 'gym consistency',
                            icon: Icons.local_fire_department_outlined,
                          ),
                          const SizedBox(height: 12),
                          DashboardStatPanel(
                            label: 'Progress',
                            value: progress,
                            caption: 'current momentum',
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Weekly Intensity',
                  title: 'Your effort across the week.',
                  subtitle:
                      'A quick view of how often you checked in and moved.',
                  trailing: Text(
                    'LAST 7 DAYS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  child: SizedBox(
                    height: 220,
                    child: DashboardChart(
                      title: 'Workout Progress',
                      seriesList: [
                        charts.Series<Map<String, dynamic>, String>(
                          id: 'ProgressParticipation',
                          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                            theme.colorScheme.primary,
                          ),
                          domainFn: (entry, _) => entry['day'] as String,
                          measureFn: (entry, _) => entry['count'] as int,
                          data: progressParticipation,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Upcoming Focus',
                  title: 'The next checkpoints to keep in motion.',
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
          onTap: () => MainNavigationScaffold.switchTab(2),
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
          onTap: () => MainNavigationScaffold.switchTab(1),
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

class _GoalRingCard extends StatelessWidget {
  final double progress;
  final String stepsText;

  const _GoalRingCard({required this.progress, required this.stepsText});

  @override
  Widget build(BuildContext context) {
    return EditorialSurface(
      padding: const EdgeInsets.all(18),
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: EditorialProgressRing(
              progress: progress,
              value: '${(progress * 100).round()}%',
              label: 'Daily Goal',
              sublabel: '$stepsText weekly logs',
              size: 148,
            ),
          ),
        ],
      ),
    );
  }
}
