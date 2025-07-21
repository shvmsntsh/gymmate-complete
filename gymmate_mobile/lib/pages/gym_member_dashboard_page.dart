import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import '../widgets/dashboard_charts.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:gymmate_mobile/services/api_dashboard_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';

class GymMemberDashboardPage extends StatefulWidget {
  const GymMemberDashboardPage({Key? key}) : super(key: key);

  @override
  State<GymMemberDashboardPage> createState() => _GymMemberDashboardPageState();
}

class _GymMemberDashboardPageState extends State<GymMemberDashboardPage> {
  List<Map<String, dynamic>> progressParticipation = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    final data = await ApiDashboardService.fetchMemberProgressParticipation(token);
    setState(() {
      progressParticipation = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentYellow = colorScheme.secondary;
    final cardBg = colorScheme.surface;
    final gold = colorScheme.primary;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userData ?? {};
    final firstName = user['firstName'] ?? authProvider.userName ?? '-';
    final userRole = user['role'] ?? authProvider.userRole ?? '-';
    final formattedRole = _formatRole(userRole);
    final gymName = authProvider.gymName;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                    child: Icon(Icons.person, color: cardBg, size: 32),
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
                _SummaryCard(label: 'Active Classes', value: (authProvider.userData?['activeClasses']?.toString() ?? '-'), accent: accentYellow, cardBg: cardBg, border: gold),
                const SizedBox(width: 12),
                _SummaryCard(label: 'Attendance', value: (authProvider.userData?['attendance']?.toString() ?? '-'), accent: accentYellow, cardBg: cardBg, border: gold),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SummaryCard(label: 'Progress', value: (authProvider.userData?['progress']?.toString() ?? '-'), accent: accentYellow, cardBg: cardBg, border: gold),
              ],
            ),
            const SizedBox(height: 24),
            // Charts Section
            Text('Progress & Participation', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: accentYellow)),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold, width: 1)),
              color: cardBg,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workout Progress', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: DashboardChart(
                        title: 'Workout Progress',
                        seriesList: [
                          charts.Series<Map<String, dynamic>, String>(
                            id: 'ProgressParticipation',
                            colorFn: (_, __) => charts.ColorUtil.fromDartColor(accentYellow),
                            domainFn: (entry, _) => entry['day'] as String,
                            measureFn: (entry, _) => entry['count'] as int,
                            data: progressParticipation,
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
                    Text('Class Participation', style: theme.textTheme.titleMedium?.copyWith(color: gold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: Container(), // Placeholder for the real chart
                    ),
                  ],
                ),
              ),
            ),
          ],
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