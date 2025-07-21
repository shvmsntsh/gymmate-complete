import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/pages/onboarding/onboarding_flow.dart';
import 'package:gymmate_mobile/pages/admin_dashboard_page.dart';
import 'package:gymmate_mobile/pages/invite_code_list_page.dart';
import 'package:gymmate_mobile/pages/profile_page.dart';
import 'package:gymmate_mobile/pages/gym_owner_dashboard_page.dart';
import 'package:gymmate_mobile/pages/gym_member_dashboard_page.dart';
import 'package:gymmate_mobile/themes/app_theme.dart';
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'GymMate',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      routes: {
        '/onboarding': (context) => const OnboardingFlow(),
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthChange(authProvider);
    });
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthChange(authProvider);
    });
  }

  void _handleAuthChange(AuthProvider authProvider) {
    final isAuth = authProvider.isAuth;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (isAuth) {
      // If already on dashboard, do nothing
      if (currentRoute != '/dashboard') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainNavigationScaffold(key: MainNavigationScaffold.navKey)),
          (route) => false,
        );
      }
    } else {
      // If already on login, do nothing
      if (currentRoute != '/login') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const GamifiedEntryScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // Show a splash/loading indicator while deciding
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
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
  final int initialTab;
  static final GlobalKey<_MainNavigationScaffoldState> navKey = GlobalKey<_MainNavigationScaffoldState>();
  const MainNavigationScaffold({Key? key, this.initialTab = 0}) : super(key: key);

  static void switchTab(int index) {
    final state = navKey.currentState;
    if (state != null) {
      state.setTab(index);
    }
  }

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
  }

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
        asset = '';
        label = '';
    }
    if (label.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final textColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
      child: SizedBox(
        height: 54,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (asset.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  asset,
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
            if (label.isNotEmpty)
              Positioned(
                left: 6,
                top: 34,
                child: (userRole == 'gym_trainer' || userRole == 'trainer' || userRole == 'superadmin' || userRole == 'gym_owner' || userRole == 'owner' || userRole == 'gym_member' || userRole == 'member')
                  ? Text(
                      label,
                      style: GoogleFonts.pacifico(
                        fontSize: 18,
                        color: textColor,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(1, 1),
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

  void setTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole = authProvider.userData?['role'] as String? ?? '';
    final isGymMember = userRole == 'gym_member';
    final isSuperadmin = userRole == 'superadmin';
    final isGymOwner = userRole == 'gym_owner';

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

    List<SalomonBottomBarItem> items = [
      SalomonBottomBarItem(
        icon: const Icon(Icons.dashboard),
        title: const Text('Dashboard'),
        selectedColor: Colors.cyanAccent.shade400,
        unselectedColor: Colors.white70,
      ),
    ];

    // Add Invites tab for superadmin and gym_owner
    if (isSuperadmin || isGymOwner) {
      pages.add(const InviteCodeListPage());
      items.add(
        SalomonBottomBarItem(
          icon: const Icon(Icons.group_add_rounded),
          title: const Text('Invites'),
          selectedColor: Colors.amber.shade400,
          unselectedColor: Colors.white70,
        ),
      );
    }

    // Add Plan/Coach for gym members
    if (isGymMember) {
      pages.add(const PlanPage());
      items.add(
        SalomonBottomBarItem(
          icon: const Icon(Icons.calendar_today),
          title: const Text('Plan'),
          selectedColor: Colors.blueAccent.shade200,
          unselectedColor: Colors.white70,
        ),
      );
      pages.add(const CoachPage());
      items.add(
        SalomonBottomBarItem(
          icon: const Icon(Icons.sports_gymnastics),
          title: const Text('Coach'),
          selectedColor: Colors.deepOrangeAccent.shade200,
          unselectedColor: Colors.white70,
        ),
      );
    }

    // Add Profile page for all roles
    pages.add(const ProfilePage());
    items.add(
      SalomonBottomBarItem(
        icon: const Icon(Icons.person),
        title: const Text('Profile'),
        selectedColor: Colors.tealAccent.shade400,
        unselectedColor: Colors.white70,
      ),
    );

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
            setTab(index);
          },
          items: items,
          backgroundColor: Colors.transparent,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }
} 