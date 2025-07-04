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

class GymOwnerDashboardPage extends StatefulWidget {
  const GymOwnerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymOwnerDashboardPage> createState() => _GymOwnerDashboardPageState();
}

class _GymOwnerDashboardPageState extends State<GymOwnerDashboardPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? gymInfo;
  List<dynamic> members = [];
  List<dynamic> trainers = [];
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
      // Fetch members
      final membersRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/gym/members'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final membersData = jsonDecode(membersRes.body);
      // Fetch registrations
      final regData = await ApiDashboardService.fetchGymRegistrationsLast7Days(token);
      // Filter trainers and members
      final allMembers = (membersData['members'] as List<dynamic>?) ?? [];
      final trainersList = allMembers.where((m) => m['role'] == 'gym_trainer').toList();
      final membersList = allMembers.where((m) => m['role'] == 'gym_member').toList();
      setState(() {
        gymInfo = gymData['member'] ?? {};
        trainers = trainersList;
        members = membersList;
        registrations = regData;
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
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final accentYellow = const Color(0xFFF8D84B);
    final userData = authProvider.userData ?? {};
    final firstName = userData['firstName'] ?? authProvider.userName ?? '-';
    final userRole = userData['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    final trainersCount = trainers.length;
    final membersCount = members.length;
    final roleCounts = {
      'Trainer': trainersCount,
      'Member': membersCount,
    };
    return Scaffold(
      backgroundColor: const Color(0xFF232112),
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
                              backgroundColor: const Color(0xFFF8D84B),
                              radius: 28,
                              child: const Icon(Icons.business, color: Colors.white, size: 32),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(firstName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                                Row(
                                  children: [
                                    Text(formattedRole, style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFFF8D84B))),
                                    if (gymName != null && gymName.isNotEmpty) ...[
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
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Summary Section
                      Text('Summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: accentYellow)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _SummaryCard(label: 'Members', value: membersCount.toString(), accent: accentYellow),
                          const SizedBox(width: 12),
                          _SummaryCard(label: 'Trainers', value: trainersCount.toString(), accent: accentYellow),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Distribution Section
                      Text('Distribution', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: accentYellow)),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentYellow, width: 1)),
                        color: theme.cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trainer/Member Distribution', style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyLarge?.color)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 180,
                                child: DashboardChart(
                                  title: 'Trainer/Member Distribution',
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentYellow, width: 1)),
                        color: theme.cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registrations (Last 7 Days)', style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: accentYellow, width: 1)),
                        color: theme.cardColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Generate Invite Code', style: theme.textTheme.titleMedium?.copyWith(color: accentYellow, fontWeight: FontWeight.bold)),
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
  const _SummaryCard({required this.label, required this.value, required this.accent});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 1.2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
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