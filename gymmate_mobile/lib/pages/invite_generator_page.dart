import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gymmate_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:provider/provider.dart';

class InviteGeneratorPage extends StatefulWidget {
  const InviteGeneratorPage({Key? key}) : super(key: key);

  @override
  State<InviteGeneratorPage> createState() => _InviteGeneratorPageState();
}

class _InviteGeneratorPageState extends State<InviteGeneratorPage> {
  String? _userRole;
  String? _generatedCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = await authService.getRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  Future<void> _generateCode(String roleToGenerate) async {
    setState(() {
      _isLoading = true;
      _generatedCode = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/invite/generate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'roleToGenerate': roleToGenerate}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _generatedCode = data['inviteCode'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invite Code'),
      ),
      body: _userRole == null
          ? const Center(child: CircularProgressIndicator())
          : _buildRoleSpecificContent(_userRole),
    );
  }

  Widget _buildRoleSpecificContent(String? role) {
    if (role == 'superadmin' || role == 'gym_owner') {
      return _buildCodeGenerator();
    }
    return const Center(
      child: Text('You do not have permission to generate invite codes.'),
    );
  }

  Widget _buildCodeGenerator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_userRole == 'superadmin') ...[
            ElevatedButton(
              onPressed: _isLoading ? null : () => _generateCode('gym_owner'),
              child: const Text('Generate Gym Owner Code'),
            ),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _isLoading ? null : () => _generateCode('gym_member'),
            child: const Text('Generate Gym Member Code'),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_generatedCode != null)
            _buildGeneratedCodeCard(),
        ],
      ),
    );
  }

  Widget _buildGeneratedCodeCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Generated Code:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _generatedCode!,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _generatedCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied to clipboard!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 