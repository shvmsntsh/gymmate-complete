import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/dashboard_charts.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'invite_code_list_page.dart';
import 'package:gymmate_mobile/services/api_dashboard_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

class GymTrainerDashboardPage extends StatefulWidget {
  const GymTrainerDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymTrainerDashboardPage> createState() => _GymTrainerDashboardPageState();
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
    final data = await ApiDashboardService.fetchTrainerAttendanceProgress(token);
    setState(() {
      attendanceProgress = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentYellow = colorScheme.secondary;
    final gold = colorScheme.primary;
    final cardBg = colorScheme.surface;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData ?? {};
    final firstName = user['firstName'] ?? authProvider.userName ?? '-';
    final userRole = user['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    return Scaffold(
      backgroundColor: cardBg,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
              // Trainer Logo and Signature
            Animate(
              effects: [
                FadeEffect(duration: 400.ms),
                SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, duration: 400.ms),
              ],
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                      backgroundColor: accentYellow,
                    radius: 28,
                      child: Icon(Icons.school, color: cardBg, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(firstName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: gold,
                          ),
                        ),
                      Row(
                        children: [
                            Text('Trainer', style: theme.textTheme.titleMedium?.copyWith(color: accentYellow)),
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
                  _SummaryCard(label: 'Assigned Members', value: (user['assignedMembers']?.toString() ?? '-'), accent: accentYellow, cardBg: cardBg, border: gold),
                const SizedBox(width: 12),
                  _SummaryCard(label: 'Classes', value: (user['classes']?.toString() ?? '-'), accent: accentYellow, cardBg: cardBg, border: gold),
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
                      Text('Class/Member Distribution', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                        child: Container(),
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
                      Text('Attendance/Progress', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: DashboardChart(
                        title: 'Attendance/Progress',
                        seriesList: [
                          charts.Series<Map<String, dynamic>, String>(
                            id: 'AttendanceProgress',
                            colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
                            domainFn: (entry, _) => entry['day'] as String,
                            measureFn: (entry, _) => entry['count'] as int,
                            data: attendanceProgress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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