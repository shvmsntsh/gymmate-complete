import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';

class TraineesListPage extends StatefulWidget {
  const TraineesListPage({Key? key}) : super(key: key);

  @override
  State<TraineesListPage> createState() => _TraineesListPageState();
}

class _TraineesListPageState extends State<TraineesListPage> {
  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> trainees = [];

  @override
  void initState() {
    super.initState();
    _fetchTrainees();
  }

  Future<void> _fetchTrainees() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await fetchGymMembers(token!);
      setState(() {
        trainees = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchGymMembers(String token) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/user/gym-members');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final List<dynamic> members = data['members'];
      return members.map((m) => {
        'name': m['name'] ?? '',
        'email': m['email'] ?? '',
        'id': m['_id'] ?? '',
      }).toList();
    } else {
      throw Exception('Failed to fetch trainees: ${res.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text('Error: $error'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Trainees')),
      body: ListView.builder(
        itemCount: trainees.length,
        itemBuilder: (context, index) {
          final trainee = trainees[index];
          return ListTile(
            leading: const Icon(Icons.person),
            title: Text(trainee['name'] ?? ''),
            subtitle: Text(trainee['email'] ?? ''),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TraineeDetailPage(
                    traineeId: trainee['id'] ?? '',
                    traineeName: trainee['name'] ?? 'Unknown',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TraineeDetailPage extends StatefulWidget {
  final String traineeId;
  final String traineeName;
  const TraineeDetailPage({required this.traineeId, required this.traineeName, Key? key}) : super(key: key);

  @override
  State<TraineeDetailPage> createState() => _TraineeDetailPageState();
}

class _TraineeDetailPageState extends State<TraineeDetailPage> {
  bool isLoading = true;
  String? error;
  Map<String, dynamic>? mealPlan;
  Map<String, dynamic>? workoutPlan;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final meal = await fetchPlan('meal', token!, widget.traineeId);
      final workout = await fetchPlan('workout', token, widget.traineeId);
      setState(() {
        mealPlan = meal;
        workoutPlan = workout;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> fetchPlan(String type, String token, String memberId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/plans/$type?memberId=$memberId');
    final res = await http.get(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Failed to fetch $type plan: ${res.body}');
    }
  }

  Future<void> savePlan(String type, Map<String, dynamic> plan) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    final url = Uri.parse('${ApiConfig.baseUrl}/api/plans/${widget.traineeId}/$type');
    final res = await http.post(url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(plan),
    );
    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type plan saved!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save $type plan: ${res.body}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text('Error: $error')));
    }
    return Scaffold(
      appBar: AppBar(title: Text('Trainee: ${widget.traineeName}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal Plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: jsonEncode(mealPlan),
              maxLines: 6,
              onChanged: (val) {
                try {
                  mealPlan = jsonDecode(val);
                } catch (_) {}
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => savePlan('meal', mealPlan ?? {}),
              child: const Text('Save Meal Plan'),
            ),
            const SizedBox(height: 24),
            Text('Workout Plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: jsonEncode(workoutPlan),
              maxLines: 6,
              onChanged: (val) {
                try {
                  workoutPlan = jsonDecode(val);
                } catch (_) {}
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => savePlan('workout', workoutPlan ?? {}),
              child: const Text('Save Workout Plan'),
            ),
          ],
        ),
      ),
    );
  }
} 
