import 'package:flutter/material.dart';
import '../utils/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class InviteGeneratorPage extends StatefulWidget {
  @override
  _InviteGeneratorPageState createState() => _InviteGeneratorPageState();
}

class _InviteGeneratorPageState extends State<InviteGeneratorPage> {
  String? inviteCode;
  String? error;
  bool isLoading = false;
  String? role;
  List<Map<String, dynamic>> inviteCodes = [];
  String filter = 'All';

  Future<void> fetchInviteCodes() async {
    final token = await AuthService.getToken();
    final role = await AuthService.getRole();
    final gymName = await AuthService.getGymName();
    final gymId = await AuthService.getGymId();

    final uri = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/invite/list');
    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      print('📡 Fetch Invite Codes Status: ${response.statusCode}');
      print('📩 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['codes'] is List) {
          final allCodes = List<Map<String, dynamic>>.from(data['codes']);
          if (role == 'gym_owner') {
            inviteCodes = allCodes.where((code) => code['gymId']?.toString() == gymId).toList();
          } else {
            inviteCodes = allCodes;
          }
          setState(() {});
        } else {
          print('⚠️ Unexpected response format for invite codes.');
        }
      } else {
        print('❌ Failed to load invite codes: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Exception fetching invite codes: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchInviteCodes();
  }

  Future<void> generateCode() async {
    final token = await AuthService.getToken();
    role = await AuthService.getRole();
    final gymName = await AuthService.getGymName();

    if (role == 'gym_member') {
      setState(() {
        error = 'Access Denied: Gym Members cannot generate codes.';
      });
      return;
    }

    print('🔐 Token: $token');
    print('👤 Role (raw): $role');
    print('🏋️ Gym Name: $gymName');

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final requestRole = role == 'superadmin' ? 'gym_owner' : 'gym_member';
      print('📤 Sending generateInviteCode with role: $requestRole');

      final generatedCode = await AuthService.generateInviteCode(
        token: token!,
        role: requestRole,
        gymName: gymName!,
      );

      print('📨 Full response from backend: $generatedCode');

      if (generatedCode != null && generatedCode is Map<String, dynamic>) {
        if (generatedCode['code'] != null) {
          setState(() {
            inviteCode = generatedCode['code'].toString();
          });
          print('✅ Invite Code parsed: $inviteCode');
          await fetchInviteCodes();
        } else {
          print('⚠️ Response missing "code" key');
          setState(() {
            error = 'Failed to generate invite code (missing code field)';
          });
        }
      } else {
        print('❌ Unexpected response type: ${generatedCode.runtimeType}');
        setState(() {
          error = 'Failed to generate invite code (invalid response format)';
        });
      }
    } catch (e) {
      print('🔥 Exception during code generation: $e');
      setState(() {
        error = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayRole = (role ?? '') == 'superadmin' ? 'Gym Owner' : 'Gym Member';

    if ((role ?? '') == 'gym_member') {
      return Scaffold(
        appBar: AppBar(title: Text('Invite Code')),
        body: Center(
          child: Text(
            'Access Denied.\nGym Members cannot generate or view invite codes.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.redAccent),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Generate $displayRole Invite Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: isLoading ? null : generateCode,
              child: Text('Generate Code'),
            ),
            SizedBox(height: 20),
            if (inviteCode != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ Here is your invite code:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SelectableText(inviteCode!, style: TextStyle(fontSize: 24)),
                ],
              ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📜 Invite Code List:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: filter,
                  items: ['All', 'Used', 'Unused'].map((value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      filter = value!;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 10),
            ...inviteCodes.where((code) {
              if (filter == 'All') return true;
              if (filter == 'Used') return code['used'] == true;
              if (filter == 'Unused') return code['used'] == false;
              return true;
            }).map((code) {
              return Card(
                margin: EdgeInsets.symmetric(vertical: 6),
                color: code['used'] ? Colors.grey[800] : Colors.grey[900],
                child: ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        code['code'] ?? 'No code',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (code['used'] == false)
                        IconButton(
                          icon: Icon(Icons.copy, color: Colors.white),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code['code']));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${code['code']}')));
                          },
                        )
                      else
                        SizedBox(width: 24) // To maintain layout alignment
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role: ${code['role'] == 'gym_owner' ? 'Gym Owner' : 'Member'}'),
                      if (code['used'] == true) Text('Used By: ${code['usedBy'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              );
            }).toList(),
            if (error != null)
              Text(error!, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}