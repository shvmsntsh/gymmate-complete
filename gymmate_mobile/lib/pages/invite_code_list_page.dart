import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class InviteCodeListPage extends StatefulWidget {
  @override
  _InviteCodeListPageState createState() => _InviteCodeListPageState();
}

class _InviteCodeListPageState extends State<InviteCodeListPage> {
  List<dynamic> inviteCodes = [];
  bool isLoading = true;
  bool showOnlyUnused = false;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchInviteCodes();
  }

  Future<void> fetchInviteCodes() async {
    try {
      final token = await AuthService.getToken();
      final role = await AuthService.getRole();
      final gymId = await AuthService.getGymId();

      print('🔐 Token: $token');
      print('👤 Role: $role');
      print('🏋️ GymId: $gymId');

      final headers = {
        'Authorization': 'Bearer $token',
      };

      final uri = Uri.parse('http://192.168.1.25:5050/api/invite/list');
      print('🌐 Sending GET to $uri with headers: $headers');

      final response = await http.get(uri, headers: headers);
      print('📦 Headers: ${response.headers}');

      print('📡 Status: ${response.statusCode}');
      print('📡 Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> codes = decoded['codes'];
        print('✅ Successfully decoded ${codes.length} codes');

        setState(() {
          inviteCodes = codes;
          isLoading = false;
        });
      } else {
        print('⚠️ Failed with status: ${response.statusCode}');
        setState(() {
          error = 'Failed to load invite codes';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Exception during fetch: $e');
      setState(() {
        error = '❌ Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Invite Codes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("Only unused"),
                          Switch(
                            value: showOnlyUnused,
                            onChanged: (value) {
                              setState(() {
                                showOnlyUnused = value;
                                print('🔄 Filter toggled: showOnlyUnused = $showOnlyUnused');
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final filteredCodes = showOnlyUnused
                                ? inviteCodes.where((c) => c['used'] == false).toList()
                                : inviteCodes;

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