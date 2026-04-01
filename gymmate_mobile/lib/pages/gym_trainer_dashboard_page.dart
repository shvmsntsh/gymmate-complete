import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';

class GymTrainerDashboardPage extends StatefulWidget {
  const GymTrainerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymTrainerDashboardPage> createState() =>
      _GymTrainerDashboardPageState();
}

class _GymTrainerDashboardPageState extends State<GymTrainerDashboardPage> {
  List<Map<String, dynamic>> attendanceProgress = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    final data = await ApiDashboardService.fetchTrainerAttendanceProgress(
      token,
    );
    if (!mounted) return;
    setState(() {
      attendanceProgress = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData ?? {};
    final firstName = user['firstName'] ?? authProvider.userName ?? 'Trainer';
    final gymName = authProvider.gymName ?? 'Your Gym';
    final assignedMembers = '${user['assignedMembers'] ?? 0}';
    final classes = '${user['classes'] ?? 0}';
    final weeklyTotal = attendanceProgress.fold<int>(
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
                  'Coach ready\n$firstName',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: 'Client Requests',
                  title:
                      '$assignedMembers athletes are in your lane right now.',
                  subtitle:
                      '$gymName is giving you a clear pulse on sessions, attendance, and who may need an extra nudge this week.',
                  metaLeft: '$classes classes',
                  metaRight: '$weeklyTotal check-ins',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(1),
                  buttonLabel: 'Open roster',
                  illustration: Image.asset(
                    'assets/images/trainer_illustration.png',
                    height: 176,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Assigned Members',
                        value: assignedMembers,
                        caption: 'current roster',
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Classes',
                        value: classes,
                        caption: 'scheduled work',
                        icon: Icons.event_available_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Today',
                  title: 'Where your attention is best spent next.',
                  trailing: TextButton(
                    onPressed: () => MainNavigationScaffold.switchTab(1),
                    child: const Text('View all'),
                  ),
                  child: Column(children: _buildTrainerFocusCards(context)),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Client Retention',
                  title: 'Weekly attendance and progress rhythm.',
                  subtitle:
                      'Use this to spot who is steady, who is slipping, and where to follow up.',
                  child: SizedBox(
                    height: 220,
                    child: DashboardChart(
                      title: 'Attendance and Progress',
                      seriesList: [
                        charts.Series<Map<String, dynamic>, String>(
                          id: 'AttendanceProgress',
                          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                            theme.colorScheme.secondary,
                          ),
                          domainFn: (entry, _) => entry['day'] as String,
                          measureFn: (entry, _) => entry['count'] as int,
                          data: attendanceProgress,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.people_outline_rounded,
                        title: 'Member Roster',
                        subtitle: 'Open the people you coach right now.',
                        onTap: () => MainNavigationScaffold.switchTab(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        subtitle: 'Refresh your own trainer details.',
                        onTap: () => MainNavigationScaffold.switchTab(2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrainerFocusCards(BuildContext context) {
    final entries = attendanceProgress.take(3).toList();
    if (entries.isEmpty) {
      return [
        DashboardListTileCard(
          title: 'Start with the roster',
          subtitle:
              'Open your trainees list to organize the next check-ins and keep everyone moving.',
          trailingTop: 'Now',
          trailingBottom: 'Coach view',
          leading: _leadingBadge(context, Icons.people_alt_rounded),
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
          title: _trainerFocusTitle(index),
          subtitle:
              '$day training window • Check who needs feedback or a quick adjustment.',
          trailingTop: '$count touches',
          trailingBottom: day.toUpperCase(),
          leading: _leadingBadge(context, Icons.fitness_center_rounded),
          onTap: () => MainNavigationScaffold.switchTab(1),
        ),
      );
    });
  }

  String _trainerFocusTitle(int index) {
    switch (index) {
      case 0:
        return 'Program review';
      case 1:
        return 'Form and recovery check';
      default:
        return 'Retention follow-up';
    }
  }

  Widget _leadingBadge(BuildContext context, IconData icon) {
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: DashboardStatPanel(
        label: title,
        value: '',
        caption: subtitle,
        icon: icon,
        accent: theme.colorScheme.primary,
        minHeight: 160,
      ),
    );
  }
}
