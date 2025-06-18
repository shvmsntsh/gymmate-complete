import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_config.dart';
import 'widgets/dashboard_charts.dart';

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
    setState(() => _isLoading = true);
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'authToken');
    final role = await storage.read(key: 'userRole');
    final gymId = await storage.read(key: 'gymId');

    // Determine endpoint based on user role
    String endpoint;
    if (role == 'superadmin') {
      endpoint = '/api/gym/all-members';
    } else if (role == 'admin') {
      endpoint = '/api/gym/members';
    } else {
      endpoint = '/api/gym/self'; // new endpoint to return only the user's own info
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final resp = await http
          .get(url, headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        List<dynamic> list;

        if (role == 'member') {
          final member = data['member'];
          list = member != null ? [member] : [];
        } else {
          list = data['members'] ?? [];
        }

        setState(() {
          _members = list;
          _error = null;
        });
      } else {
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

  List<charts.Series<ChartData, String>> createGymSampleData() {
    final data = [
      ChartData('Mon', 5),
      ChartData('Tue', 10),
      ChartData('Wed', 7),
      ChartData('Thu', 12),
      ChartData('Fri', 8),
      ChartData('Sat', 6),
      ChartData('Sun', 4),
    ];

    return [
      charts.Series<ChartData, String>(
        id: 'GymStats',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (ChartData stats, _) => stats.day,
        measureFn: (ChartData stats, _) => stats.count,
        data: data,
      )
    ];
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'GymMate Dashboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Logout',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('authToken');
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
                                seriesList: createGymSampleData(),
                                animate: true,
                                title: 'Weekly Check-ins',
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