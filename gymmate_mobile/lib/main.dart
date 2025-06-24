import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/pages/login_page.dart';
import 'package:gymmate_mobile/pages/register_page.dart';
import 'package:gymmate_mobile/pages/onboarding/onboarding_flow.dart';
import 'package:gymmate_mobile/pages/admin_dashboard_page.dart';
import 'package:gymmate_mobile/pages/invite_code_list_page.dart';
import 'package:gymmate_mobile/pages/profile_page.dart';
import 'package:gymmate_mobile/pages/gym_owner_dashboard_page.dart';
import 'package:gymmate_mobile/pages/gym_member_dashboard_page.dart';
import 'theme.dart';
import 'package:gymmate_mobile/services/auth_service.dart';
import 'package:gymmate_mobile/main.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // const storage = FlutterSecureStorage();
  // await storage.deleteAll(); // REMOVE THIS LINE: Do not clear storage on every app start
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Gymmate',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: authProvider.isAuth ? const MainNavigationScaffold() : const LoginPage(),
          routes: {
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/onboarding': (context) => const OnboardingFlow(),
          },
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

Future<bool> showLogoutConfirmation(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  ) ?? false;
}

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({super.key});

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _selectedIndex = 0;

  Widget _getDashboardForRole(String? role) {
    if (role == null) {
      // Still loading user info, show spinner
      return const Center(child: CircularProgressIndicator());
    }
    switch (role) {
      case 'superadmin':
        print('[NAV] Showing Superadmin Dashboard');
        return const AdminDashboardPage();
      case 'gym_owner':
        print('[NAV] Showing Gym Owner Dashboard');
        return const GymOwnerDashboardPage();
      case 'gym_member':
        print('[NAV] Showing Gym Member Dashboard');
        return const GymMemberDashboardPage();
      default:
        print('[NAV] Unknown role, showing fallback');
        return const Center(child: Text('Unknown role'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.userRole;

    final List<Widget> _widgetOptions = [
      _getDashboardForRole(role),
      const InviteCodeListPage(),
      const ProfilePage(),
    ];

    final List<String> titles = [
      'Dashboard',
      'View Invites',
      'Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              print('[LOGOUT] AppBar logout button clicked. Showing confirmation dialog.');
              final confirmed = await showLogoutConfirmation(context);
              print('[LOGOUT] Confirmation dialog result: ${confirmed == true ? 'YES' : 'NO'}');
              if (confirmed) {
                await Provider.of<AuthProvider>(context, listen: false).logout();
                await AuthService.logout();
                print('[LOGOUT] Session cleared. Navigating to /login using navigatorKey.');
                try {
                  navigatorKey.currentState!.pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                  print('[LOGOUT] Navigation to /login triggered.');
                } catch (e, st) {
                  print('[LOGOUT][ERROR] Navigation to /login failed: $e\n$st');
                }
              } else {
                print('[LOGOUT] NO clicked. Staying on dashboard.');
              }
            },
          ),
        ],
      ),
      body: _widgetOptions[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_membership_rounded),
            label: 'Invites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: (index) {
          print('[NAV] Tab changed to $index');
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<Map<String, String?>> _getUserInfo() async {
    final storage = const FlutterSecureStorage();
    final name = await storage.read(key: 'userName');
    final email = await storage.read(key: 'userEmail');
    final role = await storage.read(key: 'userRole');
    return {'name': name, 'email': email, 'role': role};
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: FutureBuilder<Map<String, String?>> (
            future: _getUserInfo(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final user = snapshot.data!;
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, size: 40),
                        title: Text(user['name'] ?? '-', style: Theme.of(context).textTheme.titleLarge),
                        subtitle: Text(user['email'] ?? '-', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.verified_user),
                          const SizedBox(width: 8),
                          Text('Role: ${user['role'] ?? '-'}', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Fill the rest of the screen with background color
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.background,
          ),
        ),
      ],
    );
  }
} 