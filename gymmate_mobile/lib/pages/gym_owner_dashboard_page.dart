import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import '../widgets/dashboard_charts.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'invite_code_list_page.dart';
import 'package:gymmate_mobile/services/api_dashboard_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/main.dart';

class GymOwnerDashboardPage extends StatefulWidget {
  const GymOwnerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymOwnerDashboardPage> createState() => _GymOwnerDashboardPageState();
}

class _GymOwnerDashboardPageState extends State<GymOwnerDashboardPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? gymInfo;
  int membersCount = 0;
  int trainersCount = 0;
  List<Map<String, dynamic>> registrations = [];
  bool loading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    setState(() { loading = true; });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    try {
      // Fetch gym info
      final gymRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/self'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final gymData = jsonDecode(gymRes.body);
      // Fetch dashboard stats from new endpoint
      final statsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/user/gym-dashboard-stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final statsData = jsonDecode(statsRes.body);
      setState(() {
        gymInfo = gymData['member'] ?? {};
        membersCount = statsData['membersCount'] ?? 0;
        trainersCount = statsData['trainersCount'] ?? 0;
        registrations = (statsData['registrations'] as List<dynamic>?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
        loading = false;
      });
      _controller.forward();
    } catch (e) {
      setState(() { loading = false; });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentYellow = colorScheme.secondary;
    final gold = colorScheme.primary;
    final cardBg = colorScheme.surface;
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData ?? {};
    final firstName = userData['firstName'] ?? authProvider.userName ?? '-';
    final userRole = userData['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    final roleCounts = {
      'Trainer': trainersCount,
      'Member': membersCount,
    };
    return Scaffold(
      backgroundColor: cardBg,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Animate(
                        effects: [
                          FadeEffect(duration: 400.ms),
                          SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, duration: 400.ms),
                        ],
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: accentYellow,
                              radius: 28,
                              child: Icon(Icons.business, color: cardBg, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(firstName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: gold)),
                                Row(
                                  children: [
                                    Text(formattedRole, style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
                                    if (gymName != null && gymName.isNotEmpty) ...[
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
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Summary Section
                      Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: gold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _SummaryCard(label: 'Members', value: membersCount.toString(), accent: accentYellow, cardBg: cardBg, border: gold),
                          const SizedBox(width: 12),
                          _SummaryCard(label: 'Trainers', value: trainersCount.toString(), accent: accentYellow, cardBg: cardBg, border: gold),
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
                              Text('Trainer/Member Distribution', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 180,
                                child: DashboardChart(
                                  title: 'Trainer/Member Distribution',
                                  showPercentages: true,
                                  seriesList: [
                                    charts.Series<MapEntry<String, int>, String>(
                                      id: 'Roles',
                                      colorFn: (entry, _) => charts.ColorUtil.fromDartColor(entry.key == 'Trainer' ? accentYellow : gold),
                                      domainFn: (entry, _) => entry.key,
                                      measureFn: (entry, _) => entry.value,
                                      data: roleCounts.entries.toList(),
                                      labelAccessorFn: (entry, _) {
                                        final total = trainersCount + membersCount;
                                        final percent = total > 0 ? (entry.value / total * 100).toStringAsFixed(0) : '0';
                                        return '${entry.value} (${percent}%)';
                                      },
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
                              SizedBox(
                                height: 180,
                                child: DashboardChart(
                                  title: 'Registrations (Last 7 Days)',
                                  seriesList: [
                                    charts.Series<Map<String, dynamic>, String>(
                                      id: 'Registrations',
                                      colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
                                      domainFn: (entry, _) => entry['day'] as String,
                                      measureFn: (entry, _) => entry['count'] as int,
                                      data: registrations,
                                      labelAccessorFn: (entry, _) => entry['count'].toString(),
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