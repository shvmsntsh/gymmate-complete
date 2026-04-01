import 'dart:convert';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../api/api_config.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard_charts.dart';
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
        membersCount = statsData['membersCount'] ?? 0;
        trainersCount = statsData['trainersCount'] ?? 0;
        registrations =
            (statsData['registrations'] as List<dynamic>?)
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
    final weeklyRegistrations = registrations.fold<int>(
      0,
      (sum, entry) => sum + ((entry['count'] as num?)?.toInt() ?? 0),
    );

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
                Text(gymName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: 'Performance Overview',
                  title: 'The pulse of your gym is steady and readable.',
                  subtitle:
                      'Keep branding, invites, growth, and the daily member rhythm together without losing the feel of your gym.',
                  metaLeft: '$membersCount members',
                  metaRight: '$weeklyRegistrations this week',
                  actionColor: theme.colorScheme.primary,
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
                  buttonLabel: 'Edit branding',
                  illustration: Image.asset(
                    'assets/images/owner_illustration.png',
                    height: 176,
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
                        caption: 'current floor energy',
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Coaches',
                        value: trainersCount.toString(),
                        caption: 'staff in rotation',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DashboardStatPanel(
                  label: 'Weekly Signups',
                  value: weeklyRegistrations.toString(),
                  caption: 'recent new member movement',
                  icon: Icons.trending_up_rounded,
                  minHeight: 132,
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Daily Performance',
                  title: 'Signups across the last seven days.',
                  trailing: Text(
                    'LAST 7 DAYS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  child: SizedBox(
                    height: 220,
                    child: DashboardChart(
                      title: 'Registrations',
                      seriesList: [
                        charts.Series<Map<String, dynamic>, String>(
                          id: 'Registrations',
                          colorFn: (_, __) => charts.ColorUtil.fromDartColor(
                            theme.colorScheme.primary,
                          ),
                          domainFn: (entry, _) => entry['day'] as String,
                          measureFn: (entry, _) => entry['count'] as int,
                          data: registrations,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Gym Tools',
                  title:
                      'Two quick controls that keep your brand and growth moving.',
                  child: Column(
                    children: [
                      DashboardListTileCard(
                        title: 'Branding studio',
                        subtitle:
                            'Adjust your logo, gym name, and app colors so members feel your identity everywhere.',
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
                            'Create a clean invite path for new people joining your gym.',
                        trailingTop: 'Open',
                        trailingBottom: 'Invites',
                        leading: _toolBadge(context, Icons.qr_code_2_rounded),
                        onTap: () => MainNavigationScaffold.switchTab(1),
                      ),
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
}
