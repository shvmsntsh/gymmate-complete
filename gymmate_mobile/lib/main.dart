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
import 'package:gymmate_mobile/themes/app_theme.dart';
import 'package:gymmate_mobile/services/auth_service.dart';
import 'package:gymmate_mobile/main.dart';
import 'pages/progress_page.dart';
import 'pages/plan_page.dart';
import 'pages/coach_page.dart';
import 'pages/gym_trainer_dashboard_page.dart';
import 'pages/trainees_list_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/gamified_entry_screen.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';

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
          title: 'TFT Gyms',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: authProvider.isAuth ? const MainNavigationScaffold() : const GamifiedEntryScreen(),
          routes: {
            // '/login': (context) => const LoginPage(),
            // '/register': (context) => const RegisterPage(),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset index if out of range (e.g., after logout or role change)
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.userData?['role'] as String? ?? '';
    final isGymMember = userRole == 'gym_member';
    int maxIndex = 0;
    if (isGymMember) {
      maxIndex = 4; // Dashboard, Progress, Plan, Coach, Profile
    } else if (userRole == 'gym_trainer') {
      maxIndex = 2; // Dashboard, Trainees, Profile
    } else {
      maxIndex = 2; // Dashboard, Invites, Profile
    }
    if (_selectedIndex > maxIndex) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  String _getPageTitle(int index) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userData?['role'] as String? ?? '';
    final isGymMember = userRole == 'gym_member';

    // Calculate the page index based on role and selected index
    if (index == 0) {
      return 'Dashboard';
    } else if (index == 1) {
      return isGymMember ? 'Progress' : 'Invites';
    } else if (isGymMember && index == 2) {
      return 'Plan';
    } else {
      return 'Profile';
    }
  }

  Widget _buildRoleLogoAndSignature(String userRole, BuildContext context) {
    String asset = '';
    String label = '';
    switch (userRole) {
      case 'superadmin':
        asset = 'assets/logos/superadmin_logo.png';
        label = 'Superadmin';
        break;
      case 'gym_owner':
      case 'owner':
        asset = 'assets/logos/owner_logo.png';
        label = 'Owner';
        break;
      case 'gym_trainer':
      case 'trainer':
        asset = 'assets/logos/trainer_logo.png';
        label = 'Trainer';
        break;
      case 'gym_member':
      case 'member':
        asset = 'assets/logos/member_logo_m.png';
        label = 'Member';
        break;
      default:
        asset = 'assets/logos/owner_logo.png';
        label = 'User';
    }
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: SizedBox(
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                asset,
                height: 44,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 6,
              bottom: -6, // Overlap about 10% of the logo
              child: Text(
                label,
                style: GoogleFonts.pacifico(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: theme.brightness == Brightness.dark ? Colors.black54 : Colors.white54,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      else if (userRole == 'gym_trainer')
        const GymTrainerDashboardPage()
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
    } else if (userRole == 'gym_trainer') {
      pages.add(const TraineesListPage());
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.people),
        label: 'Trainees',
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
      // Add Coach tab for gym members
      pages.add(const CoachPage());
      items.add(const BottomNavigationBarItem(
        icon: Icon(Icons.sports_gymnastics),
        label: 'Coach',
      ));
    }

    // Add Profile page for all roles
    pages.add(const ProfilePage());
    items.add(const BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ));

    // Guard: Ensure _selectedIndex is in range
    final safeIndex = (_selectedIndex < pages.length) ? _selectedIndex : 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: _buildRoleLogoAndSignature(userRole, context),
      ),
      body: pages[safeIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: SalomonBottomBar(
          currentIndex: safeIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: [
            SalomonBottomBarItem(
              icon: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              selectedColor: Colors.cyanAccent.shade400,
              unselectedColor: Colors.white70,
            ),
            if (isGymMember)
              SalomonBottomBarItem(
                icon: const Icon(Icons.show_chart),
                title: const Text('Progress'),
                selectedColor: Colors.amber.shade400,
                unselectedColor: Colors.white70,
              )
            else if (userRole == 'gym_trainer')
              SalomonBottomBarItem(
                icon: const Icon(Icons.people),
                title: const Text('Trainees'),
                selectedColor: Colors.purpleAccent.shade100,
                unselectedColor: Colors.white70,
              )
            else
              SalomonBottomBarItem(
                icon: const Icon(Icons.vpn_key),
                title: const Text('Invites'),
                selectedColor: Colors.greenAccent.shade400,
                unselectedColor: Colors.white70,
              ),
            if (isGymMember)
              SalomonBottomBarItem(
                icon: const Icon(Icons.calendar_today),
                title: const Text('Plan'),
                selectedColor: Colors.blueAccent.shade200,
                unselectedColor: Colors.white70,
              ),
            if (isGymMember)
              SalomonBottomBarItem(
                icon: const Icon(Icons.sports_gymnastics),
                title: const Text('Coach'),
                selectedColor: Colors.deepOrangeAccent.shade200,
                unselectedColor: Colors.white70,
              ),
            SalomonBottomBarItem(
              icon: const Icon(Icons.person),
              title: const Text('Profile'),
              selectedColor: Colors.tealAccent.shade400,
              unselectedColor: Colors.white70,
            ),
          ],
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }
} 