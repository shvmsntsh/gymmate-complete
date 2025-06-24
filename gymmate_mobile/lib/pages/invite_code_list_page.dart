import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymmate_mobile/services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/services/invite_service.dart';
import 'package:gymmate_mobile/models/invite_code_model.dart';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';

class InviteCodeListPage extends StatefulWidget {
  const InviteCodeListPage({super.key});

  @override
  _InviteCodeListPageState createState() => _InviteCodeListPageState();
}

class _InviteCodeListPageState extends State<InviteCodeListPage> {
  late Future<List<InviteCode>> _inviteCodesFuture;
  final InviteService _inviteService = InviteService();
  bool isLoading = true;
  String? error;
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshList();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    
    _currentUser = await _authService.getUser();
    if (_currentUser != null) {
      // The backend endpoint for this doesn't exist yet.
      // I will leave this blank for now.
      // await fetchInviteCodes(); 
    }
    
    setState(() {
      isLoading = false;
    });
  }

  void _refreshList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isAuth) {
      setState(() {
        _inviteCodesFuture = _inviteService.fetchInviteCodes(authProvider.token!);
      });
    } else {
      // Handle not being authenticated
      setState(() {
        _inviteCodesFuture = Future.error('Not authenticated');
      });
    }
  }

  Future<void> _generateCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error.')),
      );
      return;
    }

    final isSuperadmin = authProvider.userRole == 'superadmin';
    final isGymOwner = authProvider.userRole == 'gym_owner';
    final roleToGenerate = isSuperadmin ? 'gym_owner' : isGymOwner ? 'gym_member' : null;
    if (roleToGenerate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not allowed to generate invite codes.')),
      );
      return;
    }

    try {
      final newCode = await _inviteService.generateInviteCode(roleToGenerate, authProvider.token!);
      developer.log('Generated code: ${newCode.code}', name: 'InviteCodeListPage');
      _refreshList();
      _showGeneratedCodeDialog(newCode.code, roleToGenerate);
    } catch (e) {
      developer.log('Failed to generate invite code: $e', name: 'InviteCodeListPage', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to generate code: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showGeneratedCodeDialog(String code, String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this code with a new ${role == 'gym_owner' ? 'gym owner' : 'gym member'}:'),
            const SizedBox(height: 16),
            SelectableText(
              code,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard!')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<InviteCode>>(
        future: _inviteCodesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshList,
                      child: const Text('Try Again'),
                    )
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final isGymOwner = authProvider.userRole == 'gym_owner';
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_meeting_room,
                      size: 60, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    isGymOwner ? 'No Member Invite Codes Found' : 'No Invite Codes Found',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    isGymOwner
                      ? 'Generate a new code to invite gym members.'
                      : 'Generate a new code to get started.',
                    style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          } else {
            final codes = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshList(),
              child: ListView.builder(
                itemCount: codes.length,
                itemBuilder: (context, index) {
                  final code = codes[index];
                  return ListTile(
                    leading: Icon(
                      code.used ? Icons.check_circle : Icons.hourglass_empty,
                      color: code.used ? Colors.green : Colors.orange,
                    ),
                    title: Text(code.code,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Role: ${code.role} | Used: ${code.used ? 'Yes' : 'No'}'),
                    trailing:
                        Text(code.createdAt.toLocal().toString().split(' ')[0]),
                  );
                },
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateCode,
        child: const Icon(Icons.add),
        tooltip: 'Generate Invite Code',
      ),
    );
  }
}