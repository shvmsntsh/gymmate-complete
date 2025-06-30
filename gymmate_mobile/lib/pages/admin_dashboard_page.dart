import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_dashboard_service.dart';
import 'package:intl/intl.dart';

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

      print('🔄 Loading admin dashboard data...');
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        print('❌ No authentication token found');
        throw Exception('No authentication token found');
      }

      print('🔍 Fetching dashboard stats...');
      final stats = await DashboardService.fetchDashboardStats(token);
      print('📊 Received stats: $stats');

      print('🔍 Fetching categorized members...');
      final members = await DashboardService.fetchCategorizedMembers(token);
      print('👥 Received members: $members');

      setState(() {
        dashboardStats = stats;
        categorizedMembers = members;
        isLoading = false;
      });
      print('✅ Dashboard data loaded successfully');
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                // Welcome section
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome,',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          'superadmin',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (error != null)
                  Center(
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  )
                else ...[
                  // Stats Cards
                  if (dashboardStats != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Gyms',
                            dashboardStats!['gyms']?.toString() ?? '0',
                            Icons.fitness_center,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Members',
                            dashboardStats!['members']?.toString() ?? '0',
                            Icons.people,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Active Members',
                            dashboardStats!['activeMembers']?.toString() ?? '0',
                            Icons.how_to_reg,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Active Invites',
                            dashboardStats!['invites']?.toString() ?? '0',
                            Icons.mail,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                  Text(
                    'Members by Gym',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Categorized Members List
                  if (categorizedMembers.isEmpty)
                    const Center(
                      child: Text('No members data available'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: categorizedMembers.length,
                      itemBuilder: (context, index) {
                        final gym = categorizedMembers[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            title: Text(
                              gym['gymName'] ?? 'Unknown Gym',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Owner: ${gym['ownerName']} (${gym['ownerEmail']})',
                            ),
                            children: [
                              if ((gym['members'] as List).isEmpty)
                                const ListTile(
                                  title: Text('No members yet'),
                                )
                              else
                                ...List<Widget>.from(
                                  (gym['members'] as List).map((member) => ListTile(
                                    title: Text(member['name'] ?? 'Unknown'),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(member['email'] ?? ''),
                                        Text(
                                          'Joined: ${DateFormat('MMM d, yyyy').format(DateTime.parse(member['joinDate']))}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  )),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
} 