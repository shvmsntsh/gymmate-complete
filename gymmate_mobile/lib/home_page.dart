import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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
  final url = Uri.parse('http://192.168.1.25:5050/api/members'); // use your real IP
  try {
    final resp = await http.get(url).timeout(const Duration(seconds: 5));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      final list = data['members'] ?? []; // ✅ fix: safely extract array
      setState(() {
        _members = list;
        _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('GymMate'),
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
            Switch(value: _isDarkMode, onChanged: _toggleTheme),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
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
                          child: AspectRatio(
                            aspectRatio: 1.8,
                            child: DashboardChart(
                              seriesList: [],
                              title: 'Gym Member Statistics',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Members', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _members.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, i) {
                              final m = _members[i];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(m['gymName'] ?? 'Unnamed'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m['email'] != null) Text(m['email']),
                                    if (m['contact'] != null && m['contact'].toString().isNotEmpty)
                                      Text(m['contact'], style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label),
          ],
        ),
      ),
    );
  }
}