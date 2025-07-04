import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/dashboard_charts.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'invite_code_list_page.dart';
import 'package:gymmate_mobile/services/api_dashboard_service.dart';

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
      final stats = await ApiDashboardService.fetchDashboardStats(token);
      final members = await ApiDashboardService.fetchCategorizedMembers(token);
      setState(() {
        dashboardStats = stats;
        categorizedMembers = members;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentYellow = const Color(0xFFF8D84B);
    final subtleBorder = BorderSide(color: theme.dividerColor.withOpacity(0.18), width: 1);
    final cardBg = theme.cardColor.withOpacity(0.95);
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData ?? {};
    final firstName = userData['firstName'] ?? authProvider.userName ?? '-';
    final userRole = userData['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    // Role-wise counts
    final ownersCount = dashboardStats?['owners'] ?? 0;
    final membersCount = dashboardStats?['members'] ?? 0;
    final trainersCount = dashboardStats?['trainers'] ?? 0;
    // Registration stats for last 7 days
    final registrations = dashboardStats?['registrations'] ?? [];
    // For role-wise distribution chart
    final roleCounts = {
      'Owner': (ownersCount is int) ? ownersCount : int.tryParse(ownersCount.toString()) ?? 0,
      'Trainer': (trainersCount is int) ? trainersCount : int.tryParse(trainersCount.toString()) ?? 0,
      'Member': (membersCount is int) ? membersCount : int.tryParse(membersCount.toString()) ?? 0,
    };
    return Scaffold(
      backgroundColor: const Color(0xFF232112),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFF8D84B),
                      radius: 28,
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(firstName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                        Row(
                          children: [
                            Text(formattedRole, style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFFF8D84B))),
                            if (userRole != 'superadmin' && gymName != null && gymName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text('\u00b7', style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFFF8D84B))),
                              const SizedBox(width: 8),
                              Text(gymName, style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFFF8D84B))),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
                const SizedBox(height: 28),
                // Summary Section
                Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(label: 'Total Gyms', value: dashboardStats?['gyms']?.toString() ?? '-', accent: theme.textTheme.bodyLarge?.color ?? Colors.white, cardBg: cardBg, border: subtleBorder),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'Owners', value: ownersCount.toString(), accent: theme.textTheme.bodyLarge?.color ?? Colors.white, cardBg: cardBg, border: subtleBorder),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(label: 'Members', value: membersCount.toString(), accent: theme.textTheme.bodyLarge?.color ?? Colors.white, cardBg: cardBg, border: subtleBorder),
                  ],
                ),
                const SizedBox(height: 24),
                // Distribution Section
                Text('Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: subtleBorder),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role-wise Distribution', style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: DashboardChart(
                            title: 'Role-wise Distribution',
                            seriesList: [
                              charts.Series<MapEntry<String, int>, String>(
                                id: 'Roles',
                                colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
                                domainFn: (entry, _) => entry.key,
                                measureFn: (entry, _) => entry.value,
                                data: roleCounts.entries.toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: subtleBorder),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registrations (Last 7 Days)', style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: DashboardChart(
                            title: 'Weekly Gym Check-ins',
                            seriesList: [
                              charts.Series<Map<String, dynamic>, String>(
                                id: 'Registrations',
                                colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
                                domainFn: (entry, _) => entry['day'] as String,
                                measureFn: (entry, _) => entry['count'] as int,
                                data: registrations.cast<Map<String, dynamic>>(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Invite Code Section
                Text('Invite Code', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: subtleBorder),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate Invite Code', style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Create a unique code to invite new members to your gym.', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentYellow,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            // Navigate to Invite Code screen (2nd menu nav screen)
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InviteCodeListPage()));
                          },
                          child: const Text('Generate Code'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    if (role.isEmpty) return '-';
    return role.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Color cardBg;
  final BorderSide border;
  const _SummaryCard({required this.label, required this.value, required this.accent, required this.cardBg, required this.border});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: border.color, width: border.width),
          borderRadius: BorderRadius.circular(16),
          color: cardBg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodyLarge?.copyWith(color: accent)),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: accent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
} 