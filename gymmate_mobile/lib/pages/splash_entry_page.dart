import 'package:flutter/material.dart';
import 'login_page.dart';
import 'register_page.dart';

class SplashEntryPage extends StatefulWidget {
  const SplashEntryPage({Key? key}) : super(key: key);

  @override
  State<SplashEntryPage> createState() => _SplashEntryPageState();
}

class _SplashEntryPageState extends State<SplashEntryPage> {
  bool _showOptions = true;

  void _navigateTo(Widget page) async {
    setState(() => _showOptions = false);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF232112),
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _showOptions
                ? _EntryOptionsCard(
                    key: const ValueKey('entry'),
                    onLogin: () => _navigateTo(const LoginPage()),
                    onJoin: () => _navigateTo(const RegisterPage()),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _EntryOptionsCard extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onJoin;

  const _EntryOptionsCard({
    super.key,
    required this.onLogin,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2A18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Welcome to GymMate',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sign in to continue or join your gym with an invite code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onLogin,
            child: const Text('Login'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onJoin,
            child: const Text('Join a Gym'),
          ),
        ],
      ),
    );
  }
}
