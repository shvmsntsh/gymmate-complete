import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _inviteCodeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isGymNameDisabled = true;
  String? _currentRole;

  Timer? _debounce;
  String? _inviteCodeStatus; // 'valid', 'invalid', or null
  String? _inviteCodeMessage;

  Future<void> _checkInviteCodeAndSetGymName(String code) async {
    setState(() {
      _inviteCodeStatus = null;
      _inviteCodeMessage = null;
      _isGymNameDisabled = true;
      _nameCtrl.text = '';
    });

    if (code == '123456') {
      setState(() {
        _nameCtrl.text = 'T3 SuperAdmin';
        _isGymNameDisabled = true;
        _currentRole = 'superadmin';
        _inviteCodeStatus = 'valid';
        _inviteCodeMessage = 'Superadmin code accepted.';
      });
      return;
    }

    try {
      final validateUrl = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/invite/validate');
      final validateResp = await http.post(
        validateUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (validateResp.statusCode == 200) {
        final inviteData = jsonDecode(validateResp.body);
        final role = inviteData['role'];
        _currentRole = role;

        if (role == 'gym_member' && inviteData['gymId'] != null) {
          final gym = inviteData['gym'];
          final gymName = gym?['gymName'] ?? '';
          debugPrint('✅ Found gym for member: $gymName');
          setState(() {
            _nameCtrl.text = gymName;
            _isGymNameDisabled = true;
            _inviteCodeStatus = 'valid';
            _inviteCodeMessage = 'Joining gym: $gymName';
          });
          return;
        } else {
          setState(() {
            _isGymNameDisabled = false;
            _inviteCodeStatus = 'valid';
            _inviteCodeMessage = 'Valid invite code for role: $role';
          });
        }
      } else {
        setState(() {
          _inviteCodeStatus = 'invalid';
          _inviteCodeMessage = 'Invalid or expired invite code';
          _currentRole = null;
        });
      }
    } catch (_) {
      setState(() {
        _inviteCodeStatus = 'invalid';
        _inviteCodeMessage = 'Error validating invite code';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final theme = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      cardColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3EDF7),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: theme.colorScheme.background,
          appBar: AppBar(
            title: Row(
              children: [
                Image.asset(
                  'assets/images/ttt_logo.png', // make sure this path matches your asset
                  height: 36,
                ),
                const SizedBox(width: 12),
                const Text('The Training Theory'),
              ],
            ),
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center, size: 64, color: Colors.deepPurple),
                  const SizedBox(height: 16),
                  Text(
                    'Register Your Gym',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _inviteCodeCtrl,
                            decoration: InputDecoration(
                              labelText: 'Invite Code',
                              prefixIcon: const Icon(Icons.vpn_key),
                              suffixIcon: _inviteCodeStatus == 'valid'
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : _inviteCodeStatus == 'invalid'
                                      ? const Icon(Icons.cancel, color: Colors.red)
                                      : null,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (value) {
                              if (_debounce?.isActive ?? false) _debounce!.cancel();
                              _debounce = Timer(const Duration(milliseconds: 500), () {
                                if (value.trim().isNotEmpty) {
                                  _checkInviteCodeAndSetGymName(value.trim());
                                } else {
                                  setState(() {
                                    _isGymNameDisabled = true;
                                    _inviteCodeStatus = null;
                                    _inviteCodeMessage = null;
                                    _nameCtrl.text = '';
                                    _currentRole = null;
                                  });
                                }
                              });
                            },
                          ),
                          if (_inviteCodeMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    _inviteCodeStatus == 'valid' ? Icons.info : Icons.warning,
                                    size: 16,
                                    color: _inviteCodeStatus == 'valid' ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _inviteCodeMessage!,
                                      style: TextStyle(
                                        color: _inviteCodeStatus == 'valid' ? Colors.green : Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameCtrl,
                            enabled: !_isGymNameDisabled,
                            decoration: InputDecoration(
                              labelText: 'Gym Name',
                              prefixIcon: const Icon(Icons.business),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailCtrl,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: Text(_isLoading ? 'Registering...' : 'Register'),
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pushNamed(context, '/login'),
                            child: const Text('Already have an account? Login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _register() async {
    final gymName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final inviteCode = _inviteCodeCtrl.text.trim();

    if (gymName.isEmpty || email.isEmpty || password.isEmpty || inviteCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ All fields including invite code are required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String role = '';
    String? gymId;

    if (inviteCode == '123456') {
      // Hardcoded superadmin code
      role = 'superadmin';
    } else {
      // Step 1: Validate Invite Code
      final validateUrl = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/invite/validate');
      final validateResp = await http.post(
        validateUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': inviteCode}),
      );

      if (validateResp.statusCode != 200) {
        debugPrint('❌ validateResp.body: ${validateResp.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Invalid or expired invite code')),
        );
        setState(() => _isLoading = false);
        return;
      }

      final inviteData = jsonDecode(validateResp.body);
      debugPrint('📨 Invite code data: $inviteData');
      role = _currentRole ?? inviteData['role'];
      gymId = inviteData['gymId']?.toString();

      await _checkInviteCodeAndSetGymName(inviteCode);
    }

    // Step 2: Register with invite info (with debugging)
    final registerUrl = Uri.parse('http://shivams-mac-mini-m1.local:5050/api/gym/register');
    debugPrint('📤 Sending registration data: ${jsonEncode({
      'gymName': gymName,
      'email': email,
      'password': password,
      'role': role,
      'gymId': gymId,
      'inviteCode': inviteCode,
    })}');
    final registerResp = await http.post(
      registerUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'gymName': gymName,
        'email': email,
        'password': password,
        'role': role,
        'gymId': gymId,
        'inviteCode': inviteCode,
      }),
    );
    debugPrint('📬 Received registration response: ${registerResp.body}');
    debugPrint('📬 Status Code: ${registerResp.statusCode}');

    setState(() => _isLoading = false);

    if (registerResp.statusCode >= 200 && registerResp.statusCode < 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Registration successful!')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      debugPrint('❌ Full register response: ${registerResp.body}');
      final error = jsonDecode(registerResp.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: ${error['message'] ?? 'Unknown error'}')),
      );
    }
  }
}