import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../api/api_config.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';
import 'branding_settings_page.dart';

class GymOwnerDashboardPage extends StatefulWidget {
  const GymOwnerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymOwnerDashboardPage> createState() => _GymOwnerDashboardPageState();
}

class _GymOwnerDashboardPageState extends State<GymOwnerDashboardPage> {
  Map<String, dynamic>? gymInfo;
  int membersCount = 0;
  int trainersCount = 0;
  int inviteCount = 0;
  int weeklySignups = 0;
  int brandCompletion = 0;
  List<Map<String, dynamic>> registrations = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    setState(() {
      loading = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    try {
      final gymRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/self'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final gymData = jsonDecode(gymRes.body);
      final statsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/gym-dashboard-stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final statsData = jsonDecode(statsRes.body);
      if (!mounted) return;
      setState(() {
        gymInfo = gymData['gym'] ?? gymData['member'] ?? {};
        membersCount = statsData['activeMembers'] ?? statsData['membersCount'] ?? 0;
        trainersCount = statsData['coachCount'] ?? statsData['trainersCount'] ?? 0;
        inviteCount = statsData['inviteCount'] ?? 0;
        weeklySignups = statsData['weeklySignups'] ?? 0;
        brandCompletion = statsData['brandCompletion'] ?? 0;
        registrations =
            ((statsData['chartSeries'] ?? statsData['registrations']) as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final gymName = authProvider.gymName ?? gymInfo?['name'] ?? 'Your Gym';
    final computedWeeklyRegistrations = registrations.fold<int>(
      0,
      (sum, entry) => sum + (((entry['count'] ?? entry['value']) as num?)?.toInt() ?? 0),
    );
    final weeklyTotal = weeklySignups > 0 ? weeklySignups : computedWeeklyRegistrations;
    final chartPoints = registrations
        .map(
          (entry) => DashboardBarPoint(
            label: (entry['label'] ?? entry['day'] ?? '').toString(),
            value: ((entry['value'] ?? entry['count']) as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
    final bestPoint = chartPoints.isEmpty
        ? null
        : chartPoints.reduce((a, b) => a.value >= b.value ? a : b);

    if (loading && gymInfo == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const EditorialBackdrop(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: DashboardSectionCard(
            eyebrow: 'Loading',
            title: 'Pulling your gym overview together.',
            subtitle:
                'Branding, members, and signups will appear here in a moment.',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: fetchDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardHeroCard(
                  eyebrow: 'Owner Overview',
                  title: 'Your gym is moving. Here’s what needs your eye today.',
                  subtitle:
                      'Track member activity, invite new people in, and keep your brand polished without leaving the floor.',
                  metaLeft: '$membersCount active members',
                  metaRight: '$weeklyTotal signups this week',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(1),
                  buttonLabel: 'Open invites',
                  illustration: Image.asset(
                    'assets/images/owner_illustration.png',
                    height: 152,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Active Members',
                        value: membersCount.toString(),
                        caption: 'member roster today',
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Coaches',
                        value: trainersCount.toString(),
                        caption: 'currently assigned',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DashboardStatPanel(
                  label: 'Weekly Signups',
                  value: weeklyTotal.toString(),
                  caption: 'new joins in 7 days',
                  icon: Icons.trending_up_rounded,
                  minHeight: 132,
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Daily Performance',
                  title: 'Signups across the last seven days.',
                  subtitle: 'A quick read on the week so far, with your busiest signup day highlighted.',
                  trailing: Text(
                    'LAST 7 DAYS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  child: DashboardBarChartCard(
                    points: chartPoints,
                    summaryLeft: '$weeklyTotal new members this week',
                    summaryRight: bestPoint == null
                        ? null
                        : 'Best day: ${bestPoint.label}',
                    emptyTitle: 'No signup activity yet',
                    emptySubtitle:
                        'As new members join, your weekly trend will appear here.',
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Quick Actions',
                  title: 'Run the essentials in a minute.',
                  child: Column(
                    children: [
                      DashboardListTileCard(
                        title: 'Branding studio',
                        subtitle:
                            'Update logo, gym name, and colors so your gym feels consistent everywhere.',
                        trailingTop: 'Open',
                        trailingBottom: 'Branding',
                        leading: _toolBadge(context, Icons.palette_outlined),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BrandingSettingsPage(),
                            ),
                          );
                          if (mounted) {
                            fetchDashboardData();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DashboardListTileCard(
                        title: 'Invite members',
                        subtitle:
                            'Share a code for new joins and keep your member flow moving.',
                        trailingTop: 'Open',
                        trailingBottom: 'Invites',
                        leading: _toolBadge(context, Icons.qr_code_2_rounded),
                        onTap: () => MainNavigationScaffold.switchTab(1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Brand Health',
                  title: 'Your gym is showing up with $brandCompletion% brand completion.',
                  subtitle: '$gymName is carrying your current name, colors, logo, and service mix across GymMate.',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statusPill(context, '${inviteCount.toString()} open invites'),
                      _statusPill(context, '${trainersCount.toString()} coaches assigned'),
                      _statusPill(context, '${membersCount.toString()} active members'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBadge(BuildContext context, IconData icon) {
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

  Widget _statusPill(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
