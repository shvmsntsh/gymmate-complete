import 'package:flutter/material.dart';
import '../widgets/animated_entry_options.dart';
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF232112),
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _showOptions
                ? AnimatedEntryOptions(
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