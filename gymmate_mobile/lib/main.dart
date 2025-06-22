import 'package:flutter/material.dart';
import 'package:gymmate_mobile/pages/home_page.dart';
import 'package:gymmate_mobile/pages/login_page.dart';
import 'package:gymmate_mobile/pages/onboarding/onboarding_flow.dart';
import 'package:gymmate_mobile/pages/register_page.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:provider/provider.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:gymmate_mobile/theme.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, OnboardingProvider>(
          create: (_) => OnboardingProvider(),
          update: (_, auth, onboarding) =>
              onboarding!..update(auth.token, auth.userId),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AnimatedSplashScreen(
        splash: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/ttt_logo.png', height: 120),
              const SizedBox(height: 16),
              const Text('GymMate',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        nextScreen: const AuthChecker(),
        splashTransition: SplashTransition.fadeTransition,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        duration: 1500,
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/onboarding': (context) => const OnboardingFlow(),
      },
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({Key? key}) : super(key: key);

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isLoggedIn = await authService.isLoggedIn().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ AuthChecker: Timeout occurred, defaulting to not logged in');
          return false;
        },
      );
      
      print('🔍 AuthChecker: Auth check completed - isLoggedIn: $isLoggedIn');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      print('❌ AuthChecker: Error during auth check: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 AuthChecker: Building with isLoading: $_isLoading, isLoggedIn: $_isLoggedIn, error: $_error');
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_error != null) {
      print('🔍 AuthChecker: Error occurred, showing login page');
      return const LoginPage();
    }
    
    if (_isLoggedIn) {
      print('🔍 AuthChecker: User is logged in, navigating to HomePage');
      return const HomePage();
    } else {
      print('🔍 AuthChecker: User is not logged in, showing LoginPage');
      return const LoginPage();
    }
  }
} 