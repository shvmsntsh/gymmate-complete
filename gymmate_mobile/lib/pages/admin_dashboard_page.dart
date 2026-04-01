import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool isLoading = true;
  String? error;
  Map<String, dynamic>? dashboardStats;
  List<Map<String, dynamic>> categorizedMembers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      if (token == null) throw Exception('No authentication token found');
      final results = await Future.wait([
        ApiDashboardService.fetchDashboardStats(token),
        ApiDashboardService.fetchCategorizedMembers(token),
      ]);
      final stats = results[0] as Map<String, dynamic>;
      final ownersList = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      setState(() {
        dashboardStats = stats;
        categorizedMembers = ownersList;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData ?? {};
    final firstName = userData['firstName'] ?? authProvider.userName ?? 'Admin';
    final userRole = userData['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final ownersCount = categorizedMembers.length;
    final membersCount = _toInt(dashboardStats?['members']);
    final gymsCount = _toInt(dashboardStats?['gyms']);
    final invitesCount = _toInt(dashboardStats?['invites']);
    final registrations =
        (dashboardStats?['registrations'] as List<dynamic>? ?? [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();

    if (isLoading && dashboardStats == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const EditorialBackdrop(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: DashboardSectionCard(
            eyebrow: 'Loading',
            title: 'Bringing the network overview into focus.',
            subtitle:
                'Gyms, members, and invites will appear here in a moment.',
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
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GymMate Admin\n$firstName',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: formattedRole,
                  title: 'See the network clearly before you touch a thing.',
                  subtitle:
                      'Gyms, owners, members, and invites are all visible in one place so the next decision feels simple.',
                  metaLeft: '$gymsCount gyms',
                  metaRight: '$membersCount members',
                  actionColor: theme.colorScheme.primary,
                  onTap: () => MainNavigationScaffold.switchTab(1),
                  buttonLabel: 'Open invites',
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
                        label: 'Total Gyms',
                        value: gymsCount.toString(),
                        caption: 'registered locations',
                        icon: Icons.domain_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Owners',
                        value: ownersCount.toString(),
                        caption: 'active leaders',
                        icon: Icons.workspace_premium_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Members',
                        value: membersCount.toString(),
                        caption: 'network population',
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Invites',
                        value: invitesCount.toString(),
                        caption: 'open access links',
                        icon: Icons.confirmation_number_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Network Growth',
                  title: 'Member expansion across the last seven days.',
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
                          domainFn: (entry, _) {
                            final dayMap = {
                              'Monday': 'M',
                              'Tuesday': 'T',
                              'Wednesday': 'W',
                              'Thursday': 'T',
                              'Friday': 'F',
                              'Saturday': 'S',
                              'Sunday': 'S',
                            };
                            return dayMap[entry['day']] ??
                                entry['day'].toString();
                          },
                          measureFn: (entry, _) => entry['count'] as int,
                          data: registrations,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Gym Partners',
                  title: 'A quick look at the newest operators in the network.',
                  trailing: TextButton(
                    onPressed: () => MainNavigationScaffold.switchTab(1),
                    child: const Text('View all'),
                  ),
                  child: error != null
                      ? Text(
                          'We could not load gym partners right now.',
                          style: theme.textTheme.bodyMedium,
                        )
                      : Column(children: _buildOwnerCards(context)),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Network Health',
                  title: 'A simple read on the current state of operations.',
                  child: Column(
                    children: [
                      _healthRow(
                        context,
                        'Gym coverage',
                        gymsCount,
                        gymsCount > 0 ? 1.0 : 0.0,
                      ),
                      const SizedBox(height: 12),
                      _healthRow(
                        context,
                        'Owner readiness',
                        ownersCount,
                        gymsCount > 0
                            ? (ownersCount / gymsCount).clamp(0.0, 1.0)
                            : 0.0,
                      ),
                      const SizedBox(height: 12),
                      _healthRow(
                        context,
                        'Member support',
                        membersCount,
                        membersCount > 0 ? 0.86 : 0.0,
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

  List<Widget> _buildOwnerCards(BuildContext context) {
    if (categorizedMembers.isEmpty) {
      return [
        DashboardListTileCard(
          title: 'No gym owners yet',
          subtitle:
              'As owners join GymMate, they will appear here with their location details.',
          trailingTop: 'Empty',
          trailingBottom: 'Network',
          leading: _iconBadge(context, Icons.domain_disabled_outlined),
        ),
      ];
    }

    final slice = categorizedMembers.take(4).toList();
    return List.generate(slice.length, (index) {
      final owner = slice[index];
      final name =
          owner['name']?.toString() ??
          owner['firstName']?.toString() ??
          'Owner';
      final gym = owner['gymName']?.toString() ?? 'GymMate Gym';
      final email = owner['email']?.toString() ?? 'No email';
      return Padding(
        padding: EdgeInsets.only(bottom: index == slice.length - 1 ? 0 : 12),
        child: DashboardListTileCard(
          title: gym,
          subtitle: '$name • $email',
          trailingTop: 'Active',
          trailingBottom: 'Owner',
          leading: _iconBadge(context, Icons.business_center_outlined),
        ),
      );
    });
  }

  Widget _healthRow(
    BuildContext context,
    String label,
    int value,
    double progress,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            Text(value.toString(), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(999),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }

  Widget _iconBadge(BuildContext context, IconData icon) {
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '-';
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
