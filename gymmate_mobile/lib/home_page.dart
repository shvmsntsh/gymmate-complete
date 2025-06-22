import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../api/api_config.dart';
import 'widgets/dashboard_charts.dart';
import 'pages/invite_code_list_page.dart';
import 'pages/invite_generator_page.dart';
import 'services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDarkMode = false;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _members = [];
  List<charts.Series<ChartData, String>> _chartSeries = [];
  String role = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadMembers();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _isDarkMode = prefs.getBool('isDarkMode') ?? false; });
  }

  Future<void> _toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    setState(() => _isDarkMode = value);
  }

  Future<void> _loadMembers() async {
    print('🏠 HomePage._loadMembers() called');
    setState(() => _isLoading = true);
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final storage = const FlutterSecureStorage();
    
    role = await storage.read(key: 'userRole') ?? '';
    final token = authService.token; // Use token from AuthService
    final gymId = await storage.read(key: 'gymId');
    
    print('🔑 Token from AuthService: $token');
    print('🔑 Role read from storage in HomePage: $role');
    print('🔑 GymId read from storage in HomePage: $gymId');
    
    // Determine endpoint based on user role - use new user-based endpoints
    String endpoint;
    if (role == 'superadmin') {
      endpoint = '/api/auth/all-members';
    } else if (role == 'gym_owner' || role == 'admin') {
      endpoint = '/api/auth/members';
    } else {
      endpoint = '/api/auth/self'; // new endpoint to return only the logged-in gym_member's own info
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    print('🌐 Making API call to: $url');
    print('🌐 With token: $token');
    print('🌐 With role: $role');

    try {
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      print('🌐 API response status: ${resp.statusCode}');
      print('🌐 API response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        List<dynamic> list;

        if (role == 'gym_member') {
          final member = data['member'];
          list = member != null ? [member] : [];
        } else {
          list = data['members'] ?? [];
        }

        setState(() {
          _members = list;
          _error = null;
        });
        final identifier = (role == 'gym_member')
            ? await storage.read(key: 'userEmail')
            : await storage.read(key: 'gymId');
        _chartSeries = createGymSampleData(role, list, identifier ?? '');
        print('📊 Loaded ${_members.length} members for role: $role');
      } else {
        // If token is invalid or expired, log out the user
        if (resp.statusCode == 401 || resp.statusCode == 403) {
          print('🔒 Token expired or invalid. Logging out.');
          await authService.logout(); // Use AuthService logout
          
          // Use a post-frame callback to ensure navigation happens after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
        }
        throw 'Status ${resp.statusCode}: ${resp.body}';
      }
    } on TimeoutException {
      setState(() => _error = 'Request timed out');
    } catch (e, stack) {
      print('❌ ERROR: $e');
      print('🔍 STACK: $stack');
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<charts.Series<ChartData, String>> createGymSampleData(String role, List<dynamic> members, String currentUserIdentifier) {
    Map<String, int> counts = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };

    for (var m in members) {
      DateTime date = DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now();
      String day = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7];
      if (role == 'superadmin' && m['role'] == 'gym_owner') {
        counts[day] = counts[day]! + 1;
      } else if (role == 'gym_owner' && m['role'] == 'gym_member') {
        counts[day] = counts[day]! + 1;
      } else if (role == 'gym_member') {
          final logins = m['loginTimestamps'] as List<dynamic>? ?? [];
          for (final login in logins) {
            final parsed = DateTime.tryParse(login);
            if (parsed != null) {
              final now = DateTime.now();
              final weekStart = now.subtract(Duration(days: now.weekday - 1));
              final weekEnd = weekStart.add(const Duration(days: 6));
              if (!parsed.isBefore(weekStart) && !parsed.isAfter(weekEnd)) {
                final loginDay = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][parsed.weekday % 7];
                counts[loginDay] = counts[loginDay]! + 1;
              }
            }
          }
      }
    }

    final data = counts.entries.map((e) => ChartData(e.key, e.value)).toList();

    return [
      charts.Series<ChartData, String>(
        id: 'Stats',
        domainFn: (ChartData stats, _) => stats.day,
        measureFn: (ChartData stats, _) => stats.count,
        data: data,
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        labelAccessorFn: (ChartData row, _) => '${row.count}',
      )
    ];
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      routes: {
        '/invite-list': (context) => InviteCodeListPage(),
        '/invite': (context) => InviteGeneratorPage(),
      },
      home: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Image.asset(
              'assets/images/ttt_logo.png', // Adjust path if logo is in another folder
              width: 36,
              height: 36,
            ),
          ),
          title: const Text(
            'GymMate Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            FutureBuilder<String?>(
              future: const FlutterSecureStorage().read(key: 'userRole'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox.shrink();
                }
                final role = snapshot.data;
                if (role != 'gym_member') {
                  return IconButton(
                    icon: const Icon(Icons.card_giftcard),
                    tooltip: 'Generate Invite Code',
                    onPressed: () {
                      Navigator.pushNamed(context, '/invite');
                    },
                  );
                }
                return SizedBox.shrink();
              },
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Logout',
              onPressed: () async {
                final storage = const FlutterSecureStorage();
                await storage.deleteAll(); // Clear all stored credentials
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatCard('Total Members', _members.length.toString(), Icons.group),
                              _buildStatCard(
                                'Active Gyms',
                                _members.map((m) => m['gymName']).toSet().length.toString(),
                                Icons.fitness_center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: SizedBox(
                              height: 344,
                              child: DashboardChart(
                                seriesList: _chartSeries,
                                animate: true,
                                title: role == 'gym_member' ? 'Weekly Check-ins' : 'Weekly Registrations',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _members.length,
                            itemBuilder: (context, i) {
                              final m = _members[i];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 32,
                                      backgroundImage: AssetImage('assets/images/default_user.png'),
                                      backgroundColor: Colors.transparent,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            m['gymName'] ?? 'Unnamed',
                                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          if (m['email'] != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.email, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(m['email']),
                                              ],
                                            ),
                                          if (m['contact'] != null && m['contact'].toString().isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                                                  const SizedBox(width: 6),
                                                  Text(m['contact']),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

class ChartData {
  final String day;
  final int count;

  ChartData(this.day, this.count);
}