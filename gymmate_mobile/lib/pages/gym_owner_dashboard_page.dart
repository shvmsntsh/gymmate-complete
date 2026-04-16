import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../api/api_config.dart';
import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/coaching_service.dart';
import '../widgets/editorial_dashboard_mobile.dart';
import '../widgets/editorial_mobile.dart';
import 'branding_settings_page.dart';
import 'membership_plans_page.dart';
import 'membership_requests_page.dart';
import 'record_payment_page.dart';

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
  int assignedClients = 0;
  int unassignedClients = 0;
  int unreadTrainerMessages = 0;
  List<Map<String, dynamic>> trainerWorkload = [];
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
      final ownerAssignments = await CoachingService.fetchOwnerAssignments(
        token,
      );
      if (!mounted) return;
      setState(() {
        gymInfo = gymData['gym'] ?? gymData['member'] ?? {};
        membersCount =
            statsData['activeMembers'] ?? statsData['membersCount'] ?? 0;
        trainersCount =
            statsData['coachCount'] ?? statsData['trainersCount'] ?? 0;
        inviteCount = statsData['inviteCount'] ?? 0;
        weeklySignups = statsData['weeklySignups'] ?? 0;
        brandCompletion = statsData['brandCompletion'] ?? 0;
        registrations =
            ((statsData['chartSeries'] ?? statsData['registrations'])
                    as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
        assignedClients =
            (ownerAssignments['summary']?['assignedCount'] as num?)?.toInt() ??
            0;
        unassignedClients =
            (ownerAssignments['summary']?['unassignedCount'] as num?)
                ?.toInt() ??
            0;
        unreadTrainerMessages =
            (ownerAssignments['summary']?['unreadTrainerMessages'] as num?)
                ?.toInt() ??
            0;
        trainerWorkload =
            ((ownerAssignments['summary']?['trainerWorkload'])
                        as List<dynamic>? ??
                    [])
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList();
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
      (sum, entry) =>
          sum + (((entry['count'] ?? entry['value']) as num?)?.toInt() ?? 0),
    );
    final weeklyTotal = weeklySignups > 0
        ? weeklySignups
        : computedWeeklyRegistrations;
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
                  title: 'Your gym is moving.',
                  subtitle:
                      'Track activity, send invites, and keep the brand polished.',
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
                        caption: 'active today',
                        icon: Icons.people_alt_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatPanel(
                        label: 'Coaches',
                        value: trainersCount.toString(),
                        caption: 'assigned',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DashboardStatPanel(
                  label: 'Weekly Signups',
                  value: weeklyTotal.toString(),
                  caption: 'joins this week',
                  icon: Icons.trending_up_rounded,
                  minHeight: 132,
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Daily Performance',
                  title: 'Signups across seven days.',
                  subtitle: 'See the week quickly.',
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
                  eyebrow: 'Coach Operations',
                  title: 'Trainer assignments.',
                  subtitle:
                      'See linked clients, open gaps, and unread trainer replies.',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DashboardStatPanel(
                              label: 'Assigned',
                              value: assignedClients.toString(),
                              caption: 'clients linked',
                              icon: Icons.link_rounded,
                              minHeight: 132,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardStatPanel(
                              label: 'Unassigned',
                              value: unassignedClients.toString(),
                              caption: 'need owner action',
                              icon: Icons.person_search_outlined,
                              minHeight: 132,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DashboardStatPanel(
                        label: 'Unread Trainer Messages',
                        value: unreadTrainerMessages.toString(),
                        caption: 'inbox',
                        icon: Icons.forum_outlined,
                        minHeight: 132,
                      ),
                      if (trainerWorkload.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...List.generate(trainerWorkload.length, (index) {
                          final workload = trainerWorkload[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == trainerWorkload.length - 1
                                  ? 0
                                  : 12,
                            ),
                            child: DashboardListTileCard(
                              title: (workload['name'] ?? 'Trainer').toString(),
                              subtitle:
                                  'Current assigned load across this gym.',
                              trailingTop:
                                  '${(workload['clientCount'] as num?)?.toInt() ?? 0} clients',
                              trailingBottom: 'WORKLOAD',
                              leading: _toolBadge(
                                context,
                                Icons.badge_outlined,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Quick Actions',
                  title: 'Run the essentials fast.',
                  child: Column(
                    children: [
                      DashboardListTileCard(
                        title: 'Branding studio',
                        subtitle: 'Update logo, name, and colors.',
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
                        subtitle: 'Share codes for new joins.',
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
                  eyebrow: 'Membership',
                  title: 'Plans, requests & payments.',
                  child: Column(
                    children: [
                      DashboardListTileCard(
                        title: 'Membership plans',
                        subtitle: 'Create and manage plan offerings.',
                        trailingTop: 'Open',
                        trailingBottom: 'Plans',
                        leading: _toolBadge(
                          context,
                          Icons.card_membership_rounded,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MembershipPlansPage(),
                            ),
                          );
                          if (mounted) fetchDashboardData();
                        },
                      ),
                      const SizedBox(height: 12),
                      DashboardListTileCard(
                        title: 'Membership requests',
                        subtitle: 'Approve or reject member requests.',
                        trailingTop: 'Open',
                        trailingBottom: 'Requests',
                        leading: _toolBadge(
                          context,
                          Icons.pending_actions_rounded,
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MembershipRequestsPage(),
                            ),
                          );
                          if (mounted) fetchDashboardData();
                        },
                      ),
                      const SizedBox(height: 12),
                      DashboardListTileCard(
                        title: 'Record payment',
                        subtitle: 'Log a payment and activate membership.',
                        trailingTop: 'Open',
                        trailingBottom: 'Payments',
                        leading: _toolBadge(
                          context,
                          Icons.currency_rupee_rounded,
                        ),
                        onTap: () async {
                          final members = await _fetchMembersForPayment();
                          if (!context.mounted || members.isEmpty) return;
                          if (members.length == 1) {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RecordPaymentPage(
                                  memberId: members.first['id'].toString(),
                                  memberName:
                                      members.first['name']?.toString() ??
                                      'Member',
                                  memberEmail: members.first['email']
                                      ?.toString(),
                                ),
                              ),
                            );
                          } else {
                            await _showMemberPickerForPayment(members);
                          }
                          if (context.mounted) fetchDashboardData();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                DashboardSectionCard(
                  eyebrow: 'Brand Health',
                  title: '$brandCompletion% brand completion.',
                  subtitle:
                      '$gymName is using your current name, colors, logo, and services.',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statusPill(
                        context,
                        '${inviteCount.toString()} open invites',
                      ),
                      _statusPill(
                        context,
                        '${trainersCount.toString()} coaches assigned',
                      ),
                      _statusPill(
                        context,
                        '${membersCount.toString()} active members',
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

  Future<List<Map<String, dynamic>>> _fetchMembersForPayment() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return [];
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/owner/members'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(res.body);
      final members =
          data['members'] as List<dynamic>? ??
          data['data'] as List<dynamic>? ??
          [];
      return members.map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _showMemberPickerForPayment(
    List<Map<String, dynamic>> members,
  ) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Member',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final member = members[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (member['name']?.toString() ?? '?')[0]
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(member['name']?.toString() ?? 'Unknown'),
                          subtitle: Text(member['email']?.toString() ?? ''),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () => Navigator.pop(context, member),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (selected != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecordPaymentPage(
            memberId: selected['id'].toString(),
            memberName: selected['name']?.toString() ?? 'Member',
            memberEmail: selected['email']?.toString(),
          ),
        ),
      );
    }
  }

  Widget _statusPill(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.54,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Text(label, style: theme.textTheme.labelLarge),
    );
  }
}
