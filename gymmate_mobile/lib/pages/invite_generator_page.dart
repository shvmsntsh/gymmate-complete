import 'package:flutter/material.dart';
import '../utils/auth_service.dart';

class InviteGeneratorPage extends StatefulWidget {
  @override
  _InviteGeneratorPageState createState() => _InviteGeneratorPageState();
}

class _InviteGeneratorPageState extends State<InviteGeneratorPage> {
  String? inviteCode;
  String? error;
  bool isLoading = false;
  String? role;

  Future<void> generateCode() async {
    final token = await AuthService.getToken();
    role = await AuthService.getRole();
    final gymName = await AuthService.getGymName();

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
            if (error != null)
              Text(error!, style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}