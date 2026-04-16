import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/coaching_service.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';

class GymTrainerDashboardPage extends StatefulWidget {
  const GymTrainerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymTrainerDashboardPage> createState() =>
      _GymTrainerDashboardPageState();
}

class _GymTrainerDashboardPageState extends State<GymTrainerDashboardPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _chartSeries = [];
  List<Map<String, dynamic>> _focusClients = [];
  int _assignedClientsCount = 0;
  int _completedTodayCount = 0;
  int _needsAttentionCount = 0;
  int _unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final payload = await CoachingService.fetchTrainerDashboard(token);
      if (!mounted) return;
      setState(() {
        _chartSeries = (payload['chartSeries'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _focusClients = (payload['focusClients'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _assignedClientsCount =
            (payload['assignedClientsCount'] as num?)?.toInt() ?? 0;
        _completedTodayCount =
            (payload['completedTodayCount'] as num?)?.toInt() ?? 0;
        _needsAttentionCount =
            (payload['needsAttentionCount'] as num?)?.toInt() ?? 0;
        _unreadMessagesCount =
            (payload['unreadMessagesCount'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyTrainerDashboardError(error.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData ?? {};
    final firstName = user['firstName'] ?? authProvider.userName ?? 'Trainer';
    final gymName = authProvider.gymName ?? 'Your Gym';
    final chartPoints = _chartSeries
        .map(
          (entry) => DashboardBarPoint(
            label: (entry['label'] ?? '').toString(),
            value: (entry['value'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
    final weeklyTotal = chartPoints.fold<int>(
      0,
      (sum, point) => sum + point.value,
    );
    final focusEntries = _focusClients.take(2).toList();

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
                _TrainerHeroCard(
                  gymName: gymName,
                  assignedClientsCount: _assignedClientsCount,
                  completedTodayCount: _completedTodayCount,
                  needsAttentionCount: _needsAttentionCount,
                  onOpenClients: () => MainNavigationScaffold.switchTab(1),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TrainerStatCard(
                        label: 'Assigned Clients',
                        value: '$_assignedClientsCount',
                        caption: 'coaching load',
                        icon: Icons.people_alt_outlined,
                        tone: const Color(0xFFF4D14A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TrainerStatCard(
                        label: 'Unread Messages',
                        value: '$_unreadMessagesCount',
                        caption: 'owner + clients',
                        icon: Icons.forum_outlined,
                        tone: const Color(0xFFF2B467),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const _TrainerStateCard(
                    eyebrow: 'Weekly Check-ins',
                    title: 'Loading your coaching pulse',
                    subtitle: 'Pulling assigned client activity now.',
                    loading: true,
                  )
                else if (_error != null)
                  _TrainerStateCard(
                    eyebrow: 'Needs Attention',
                    title: 'The client dashboard could not load right now.',
                    subtitle: _error!,
                    action: EditorialPrimaryButton(
                      label: 'Retry',
                      onPressed: _loadData,
                    ),
                  )
                else
                  _TrainerChartCard(
                    points: chartPoints,
                    completedTodayCount: _completedTodayCount,
                    weeklyTotal: weeklyTotal,
                  ),
                const SizedBox(height: 18),
                _TrainerFocusSection(
                  entries: focusEntries,
                  onViewAll: () => MainNavigationScaffold.switchTab(1),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.people_outline_rounded,
                        title: 'Clients',
                        subtitle: 'Open your active clients.',
                        onTap: () => MainNavigationScaffold.switchTab(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.forum_outlined,
                        title: 'Messages',
                        subtitle: 'Reply fast from one place.',
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
}

String _friendlyTrainerDashboardError(String raw) {
  final message = raw.replaceFirst('Exception: ', '');
  if (message.contains('403') ||
      message.toLowerCase().contains('invalid or expired token')) {
    return 'Your session expired. Please sign in again.';
  }
  if (message.contains('Failed with status')) {
    return 'We could not load the dashboard right now.';
  }
  return message;
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
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: _TrainerActionCard(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

class _TrainerHeroCard extends StatelessWidget {
  final String gymName;
  final int assignedClientsCount;
  final int completedTodayCount;
  final int needsAttentionCount;
  final VoidCallback onOpenClients;

  const _TrainerHeroCard({
    required this.gymName,
    required this.assignedClientsCount,
    required this.completedTodayCount,
    required this.needsAttentionCount,
    required this.onOpenClients,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryText = Color(0xFFF7F2EA);
    const secondaryText = Color(0xFFD8CDC1);
    final title = assignedClientsCount == 0
        ? 'No clients linked yet.'
        : '$assignedClientsCount clients are linked right now.';
    final subtitle = assignedClientsCount == 0
        ? '$gymName has not linked clients to you yet.'
        : 'Track check-ins, spot drop-offs, and reply fast.';

    return EditorialSurface(
      padding: EdgeInsets.zero,
      radius: 32,
      color: const Color(0xFF1D1917),
      border: Border.all(color: const Color(0xFF3A2E22)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.28),
          blurRadius: 32,
          offset: const Offset(0, 18),
        ),
      ],
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(32)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF241F1B), Color(0xFF151210)],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x33F4D14A),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x55F4D14A)),
                  ),
                  child: Text(
                    'COACH PULSE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFF4D14A),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2416),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x55F4D14A)),
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: Color(0xFFF4D14A),
                    size: 24,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: secondaryText),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TrainerMetricPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: '$completedTodayCount completed today',
                ),
                _TrainerMetricPill(
                  icon: Icons.flag_outlined,
                  label: '$needsAttentionCount need follow-up',
                ),
              ],
            ),
            const SizedBox(height: 14),
            EditorialPrimaryButton(
              label: 'Open clients',
              onPressed: onOpenClients,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrainerMetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFF4D14A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFFE1D7CD),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color tone;

  const _TrainerStatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryText = Color(0xFFF7F2EA);
    const secondaryText = Color(0xFFC9BFB4);
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B18),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF362B22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: primaryText),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFFE4D4C3),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(color: secondaryText),
          ),
        ],
      ),
    );
  }
}

class _TrainerStateCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool loading;
  final Widget? action;

  const _TrainerStateCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.loading = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryText = Color(0xFFF7F2EA);
    const secondaryText = Color(0xFFD6C9BA);
    return EditorialSurface(
      radius: 30,
      color: const Color(0xFF1D1917),
      border: Border.all(color: const Color(0xFF352B21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFFF4D14A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(color: primaryText),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(color: secondaryText),
          ),
          if (loading) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class _TrainerChartCard extends StatelessWidget {
  final List<DashboardBarPoint> points;
  final int completedTodayCount;
  final int weeklyTotal;

  const _TrainerChartCard({
    required this.points,
    required this.completedTodayCount,
    required this.weeklyTotal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const primaryText = Color(0xFFF7F2EA);
    const secondaryText = Color(0xFFD6C9BA);
    final highestValue = points.isEmpty
        ? 0
        : points.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    final hasData = highestValue > 0;
    final maxValue = highestValue > 0 ? highestValue : 1;

    return EditorialSurface(
      radius: 30,
      color: const Color(0xFF1D1917),
      border: Border.all(color: const Color(0xFF352B21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLIENT RETENTION',
            style: theme.textTheme.labelMedium?.copyWith(
              color: const Color(0xFFF4D14A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Weekly client check-ins.',
            style: theme.textTheme.headlineSmall?.copyWith(color: primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'See who is steady and who needs a nudge.',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF232111),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x664F461F)),
            ),
            child: hasData
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TrainerMiniPill(
                            label: '$completedTodayCount completed today',
                          ),
                          const SizedBox(width: 8),
                          _TrainerMiniPill(
                            label: '$weeklyTotal total check-ins',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 184,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(points.length, (index) {
                            final point = points[index];
                            final fraction = point.value / maxValue;
                            final isPeak =
                                point.value == highestValue && highestValue > 0;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${point.value}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: const Color(0xFFF7EBC4),
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: 34,
                                      height: 24 + (fraction * 118),
                                      decoration: BoxDecoration(
                                        color: isPeak
                                            ? const Color(0xFFF4D14A)
                                            : const Color(0xFFE0B973),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFF4D14A,
                                            ).withValues(alpha: 0.18),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      point.label,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: const Color(0xFFD0C5AF),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No client activity yet',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assigned client check-ins will appear here as soon as activity starts coming in.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrainerMiniPill extends StatelessWidget {
  final String label;

  const _TrainerMiniPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x331E1A12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55F0E1BC)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _TrainerFocusSection extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final VoidCallback onViewAll;

  const _TrainerFocusSection({required this.entries, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorialSurface(
      radius: 30,
      color: const Color(0xFF1D1917),
      border: Border.all(color: const Color(0xFF352B21)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFFF4D14A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Start with these clients.',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These likely need the next action.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _TrainerFocusTile(
              title: 'Start with clients',
              subtitle: 'Open your client list and start the next follow-up.',
              progress: 'Now',
              footer: 'CLIENTS',
            )
          else
            Column(
              children: List.generate(entries.length, (index) {
                final entry = entries[index];
                final unread =
                    ((entry['unreadMessages'] as num?)?.toInt() ?? 0);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == entries.length - 1 ? 0 : 12,
                  ),
                  child: _TrainerFocusTile(
                    title: (entry['name'] ?? 'Client').toString(),
                    subtitle: _trainerFocusSubtitle(entry),
                    progress:
                        '${(((entry['todayCompletion'] ?? 0) as num).toDouble() * 100).round()}%',
                    footer: unread > 0 ? '$unread MSG' : 'TODAY',
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  static String _trainerFocusSubtitle(Map<String, dynamic> entry) {
    final status = switch ((entry['status'] ?? '').toString()) {
      'completed' => 'Completed today',
      'inactive' => 'Inactive',
      'needs_attention' => 'Needs follow-up',
      _ => 'Active today',
    };
    final goal =
        entry['fitnessGoals'] is List &&
            (entry['fitnessGoals'] as List).isNotEmpty
        ? (entry['fitnessGoals'] as List).first.toString().replaceAll('_', ' ')
        : 'general fitness';
    return '$status • ${goal.toLowerCase()}';
  }
}

class _TrainerFocusTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String progress;
  final String footer;

  const _TrainerFocusTile({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF26211B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF3A3027)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x33F4D14A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFFF4D14A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                progress,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFFF4D14A),
                ),
              ),
              const SizedBox(height: 4),
              Text(footer, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrainerActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B18),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF352B21)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x33F4D14A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFF4D14A)),
          ),
          const SizedBox(height: 18),
          Text(title.toUpperCase(), style: theme.textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
