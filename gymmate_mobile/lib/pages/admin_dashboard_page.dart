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
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/main.dart';

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
      final ownersList = await ApiDashboardService.fetchCategorizedMembers(token);
      print('🟡 [AdminDashboardPage] dashboardStats: ' + stats.toString());
      print('🟡 [AdminDashboardPage] categorizedMembers: ' + ownersList.toString());
      setState(() {
        dashboardStats = stats;
        categorizedMembers = ownersList;
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
    final colorScheme = theme.colorScheme;
    final accentYellow = colorScheme.secondary;
    final gold = colorScheme.primary;
    final cardBg = colorScheme.surface;
    final subtleBorder = BorderSide(color: gold.withOpacity(0.18), width: 1);
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData ?? {};
    final firstName = userData['firstName'] ?? authProvider.userName ?? '-';
    final userRole = userData['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    // Role-wise counts
    final ownersCount = categorizedMembers.length;
    final membersCount = dashboardStats?['members'] ?? 0;
    final trainersCount = dashboardStats?['trainers'] ?? 0;
    // Registration stats for last 7 days
    final registrations = dashboardStats?['registrations'] ?? [];
    // For role-wise distribution chart
    final roleCounts = {
      'Owner': ownersCount,
      'Trainer': (trainersCount is int) ? trainersCount : int.tryParse(trainersCount.toString()) ?? 0,
      'Member': (membersCount is int) ? membersCount : int.tryParse(membersCount.toString()) ?? 0,
    };
    return Scaffold(
      backgroundColor: cardBg,
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
                      backgroundColor: accentYellow,
                      radius: 28,
                      child: Icon(Icons.admin_panel_settings, color: cardBg, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(firstName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: gold)),
                        Row(
                          children: [
                            Text(formattedRole, style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
                            if (userRole != 'superadmin' && gymName != null && gymName.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text('•', style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
                              const SizedBox(width: 8),
                              Text(gymName, style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
                            ]
                          ],
                        ),
                      ],
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
                const SizedBox(height: 28),
                // Summary Section
                Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: gold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(label: 'Total Gyms', value: dashboardStats?['gyms']?.toString() ?? '-', accent: accentYellow, cardBg: cardBg, border: gold),
                    const SizedBox(width: 12),
                    _SummaryCard(label: 'Owners', value: ownersCount.toString(), accent: accentYellow, cardBg: cardBg, border: gold),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryCard(label: 'Members', value: membersCount.toString(), accent: accentYellow, cardBg: cardBg, border: gold),
                  ],
                ),
                const SizedBox(height: 24),
                // Distribution Section
                Text('Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: accentYellow)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold, width: 1)),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Role-wise Distribution', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: DashboardChart(
                            title: 'Role-wise Distribution',
                            seriesList: [
                              charts.Series<MapEntry<String, int>, String>(
                                id: 'Roles',
                                colorFn: (entry, _) {
                                  final colorMap = {
                                    'Owner': charts.ColorUtil.fromDartColor(Colors.blue),
                                    'Trainer': charts.ColorUtil.fromDartColor(Colors.green),
                                    'Member': charts.ColorUtil.fromDartColor(Colors.orange),
                                  };
                                  return colorMap[entry.key] ?? charts.MaterialPalette.gray.shadeDefault;
                                },
                                domainFn: (entry, _) => entry.key,
                                measureFn: (entry, _) => entry.value,
                                data: roleCounts.entries.toList(),
                                labelAccessorFn: (entry, _) => entry.value > 0 ? entry.value.toString() : '',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold, width: 1)),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registrations (Last 7 Days)', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: DashboardChart(
                            title: 'Weekly Gym Check-ins',
                            seriesList: [
                              charts.Series<Map<String, dynamic>, String>(
                                id: 'Registrations',
                                colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
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
                                  return dayMap[entry['day']] ?? entry['day'].substring(0, 1);
                                },
                                measureFn: (entry, _) => entry['count'] as int,
                                data: registrations.cast<Map<String, dynamic>>(),
                                labelAccessorFn: (entry, _) => (entry['count'] ?? 0) > 0 ? entry['count'].toString() : '',
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
                Text('Invite Code', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: accentYellow)),
                const SizedBox(height: 12),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold, width: 1)),
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Generate Invite Code', style: theme.textTheme.titleMedium?.copyWith(color: gold, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Create a unique code to invite new members to your gym.', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 12),
                        // Animated golden Generate Code button
                        GestureDetector(
                          onTap: () {
                            MainNavigationScaffold.switchTab(1);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'Generate Code',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scaleXY(begin: 0.95, end: 1.0, duration: 400.ms, curve: Curves.easeOutBack),
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
  final Color border;
  const _SummaryCard({required this.label, required this.value, required this.accent, required this.cardBg, required this.border});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: border, width: 1.2),
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