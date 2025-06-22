import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymmate_mobile/services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gymmate_mobile/api/api_config.dart';

class InviteCodeListPage extends StatefulWidget {
  @override
  _InviteCodeListPageState createState() => _InviteCodeListPageState();
}

class _InviteCodeListPageState extends State<InviteCodeListPage> {
  List<dynamic> inviteCodes = [];
  bool isLoading = true;
  String? error;
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  Future<void> _generateCode() async {
    if (_currentUser == null) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final token = await _authService.getToken();
      final role = _currentUser!['role'];
      final roleToGenerate = role == 'superadmin' ? 'gym_owner' : 'gym_member';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/invite/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'roleToGenerate': roleToGenerate}),
      );

      if (response.statusCode == 201) {
        // Refresh list
        // await fetchInviteCodes();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['message'] ?? 'Failed to generate code';
        });
      }
    } catch (e) {
      setState(() {
        error = 'An error occurred during code generation.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Invite Codes'),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _generateCode,
            tooltip: 'Generate New Code',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                : Column(
                    children: [
                      const SizedBox(height: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final filteredCodes = inviteCodes;

                            return ListView.builder(
                              itemCount: filteredCodes.length,
                              itemBuilder: (context, index) {
                                final code = filteredCodes[index]['code'];
                                final role = filteredCodes[index]['role'];
                                final used = filteredCodes[index]['used'];

                                Color roleColor;
                                switch (role) {
                                  case 'gym_owner':
                                    roleColor = Colors.blue.shade100;
                                    break;
                                  case 'gym_member':
                                    roleColor = Colors.green.shade100;
                                    break;
                                  default:
                                    roleColor = Colors.grey.shade200;
                                }

                                return Card(
                                  color: roleColor,
                                  elevation: 3,
                                  child: ListTile(
                                    title: Text('$code (${role.toUpperCase()})'),
                                    subtitle: Text(used ? '🟥 Used' : '🟩 Not used'),
                                    trailing: IconButton(
                                      icon: Icon(Icons.copy),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: code));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Code copied to clipboard')),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}