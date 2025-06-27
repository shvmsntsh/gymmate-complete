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
import 'pages/progress_page.dart';
import 'pages/plan_page.dart';

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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // For gym_member, check onboarding status
    if (role == 'gym_member' && !authProvider.hasCompletedOnboarding) {
      print('[NAV] New gym member detected, showing onboarding flow');
      return const OnboardingFlow();
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
    final userRole = authProvider.userData?['role'] as String? ?? '';
    final isGymMember = userRole == 'gym_member';

    // Check for onboarding status for gym members
    if (isGymMember && !authProvider.hasCompletedOnboarding) {
      return const OnboardingFlow();
    }

    List<Widget> pages = [
      if (userRole == 'gym_member')
        const GymMemberDashboardPage()
      else if (userRole == 'gym_owner')
        const GymOwnerDashboardPage()
      else
        const AdminDashboardPage(),
    ];

    List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
    ];

    // Add Progress/Invites based on role
    if (isGymMember) {
      pages.add(const ProgressPage());
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.show_chart),
        label: 'Progress',
      ));
    } else {
      pages.add(const InviteCodeListPage());
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.vpn_key),
        label: 'Invites',
      ));
    }

    // Add Plan page only for gym members
    if (isGymMember) {
      pages.add(const PlanPage());
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.calendar_today),
        label: 'Plan',
      ));
    }

    // Add Profile page for all roles
    pages.add(const ProfilePage());
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(pages[_selectedIndex].toString()),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              print('[LOGOUT] AppBar logout button clicked. Showing confirmation dialog.');
              final confirmed = await showLogoutConfirmation(context);
              print('[LOGOUT] Confirmation dialog result: \\${confirmed == true ? 'YES' : 'NO'}');
              if (confirmed) {
                // Reset selected index before logging out to prevent out of bounds error
                setState(() {
                  _selectedIndex = 0;
                });
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
                  print('[LOGOUT][ERROR] Navigation to /login failed: \\${e}\\n\\${st}');
                }
              } else {
                print('[LOGOUT] NO clicked. Staying on dashboard.');
              }
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: const Color(0xFF2C2C2E),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFF2C2C2E),
          selectedItemColor: Colors.cyan,
          unselectedItemColor: Colors.white54,
          items: items,
        ),
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