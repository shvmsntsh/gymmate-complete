import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gymmate_mobile/api/api_client.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/providers/onboarding_provider.dart';
import 'package:gymmate_mobile/pages/onboarding/onboarding_flow.dart';
import 'package:gymmate_mobile/pages/admin_dashboard_page.dart';
import 'package:gymmate_mobile/pages/invite_code_list_page.dart';
import 'package:gymmate_mobile/pages/profile_page.dart';
import 'package:gymmate_mobile/pages/gym_member_dashboard_page.dart';
import 'package:gymmate_mobile/pages/splash_screen.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:gymmate_mobile/themes/app_theme.dart';
import 'pages/member_membership_page.dart';
import 'pages/plan_page.dart';
import 'pages/coach_page.dart';
import 'pages/gym_trainer_dashboard_page.dart';
import 'pages/gamified_entry_screen.dart';
import 'pages/required_password_setup_page.dart';
import 'pages/trainer_clients_page.dart';
import 'pages/trainer_messages_page.dart';
import 'package:gymmate_mobile/utils/branding_utils.dart';
import 'package:gymmate_mobile/utils/role_utils.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // India-first: default DateFormat/NumberFormat to en_IN app-wide. Load the
  // locale's date symbols first so DateFormat doesn't throw for en_IN.
  await initializeDateFormatting('en_IN', null);
  Intl.defaultLocale = 'en_IN';
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
        final branding = authProvider.branding;
        final primary = colorFromHex(
          branding['primaryColor'],
          fallback: const Color(0xFFB59F5B),
        );
        final secondary = colorFromHex(
          branding['secondaryColor'],
          fallback: const Color(0xFFF8D84B),
        );

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: branding['gymName'] ?? 'GymMate',
          theme: AppTheme.buildLightTheme(
            primary: primary,
            secondary: secondary,
          ),
          darkTheme: AppTheme.buildDarkTheme(
            primary: primary,
            secondary: secondary,
          ),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          supportedLocales: const [Locale('en', 'IN'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
          routes: {'/onboarding': (context) => const OnboardingFlow()},
        );
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
  bool _isReady = false;
  static const _minimumLoader = Duration(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    _bootstrapAuth();
  }

  Future<void> _bootstrapAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Route an expired/invalid session (any 401) back to the entry screen.
    // logout() flips isAuth false and notifies, so the AuthGate Consumer
    // rebuilds to GamifiedEntryScreen automatically. Guarded so a burst of
    // concurrent 401s only triggers one logout.
    ApiClient.onUnauthorized = () {
      if (!authProvider.isAuth) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authProvider.isAuth) authProvider.logout();
      });
    };
    final startedAt = DateTime.now();
    await authProvider.tryAutoLogin();
    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minimumLoader - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) {
      return;
    }
    setState(() => _isReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const BrandedLoadingScreen(
        title: 'GymMate',
        subtitle: 'Loading your journey',
        showTagline: true,
        lightweight: true,
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuth) {
          return MainNavigationScaffold(key: MainNavigationScaffold.navKey);
        }
        return const GamifiedEntryScreen();
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      ) ??
      false;
}

class MainNavigationScaffold extends StatefulWidget {
  final int initialTab;
  static final GlobalKey<MainNavigationScaffoldState> navKey =
      GlobalKey<MainNavigationScaffoldState>();
  const MainNavigationScaffold({Key? key, this.initialTab = 0})
    : super(key: key);

  static void switchTab(int index) {
    final state = navKey.currentState;
    if (state != null) {
      state.setTab(index);
    }
  }

  @override
  State<MainNavigationScaffold> createState() => MainNavigationScaffoldState();
}

class MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  late int _selectedIndex;
  bool _appliedWebTabOverride = false;

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
    final userRole =
        normalizeRole(
          authProvider.userData?['role'] as String? ?? authProvider.userRole,
        ) ??
        '';
    final isGymMember = isMemberRole(userRole);
    int maxIndex = 0;
    if (isGymMember) {
      maxIndex = 4; // Dashboard, Plan, Membership, Coach, Profile
    } else if (isTrainerRole(userRole)) {
      maxIndex = 3; // Dashboard, Clients, Messages, Profile
    } else {
      maxIndex = 2; // Dashboard, Invites, Profile
    }
    if (_selectedIndex > maxIndex) {
      setState(() {
        _selectedIndex = 0;
      });
    }
    if (!_appliedWebTabOverride && kIsWeb) {
      final requestedIndex = _tabIndexFromQuery(userRole);
      if (requestedIndex != null && requestedIndex <= maxIndex) {
        _appliedWebTabOverride = true;
        setState(() {
          _selectedIndex = requestedIndex;
        });
      } else {
        _appliedWebTabOverride = true;
      }
    }
  }

  int? _tabIndexFromQuery(String userRole) {
    final tab = Uri.base.queryParameters['tab']?.trim().toLowerCase();
    if (tab == null || tab.isEmpty) return null;
    if (isTrainerRole(userRole)) {
      switch (tab) {
        case 'dashboard':
          return 0;
        case 'clients':
          return 1;
        case 'messages':
          return 2;
        case 'profile':
          return 3;
      }
    }
    if (isMemberRole(userRole)) {
      switch (tab) {
        case 'dashboard':
          return 0;
        case 'plan':
          return 1;
        case 'membership':
          return 2;
        case 'coach':
          return 3;
        case 'profile':
          return 4;
      }
    }
    switch (tab) {
      case 'dashboard':
        return 0;
      case 'invites':
        return 1;
      case 'profile':
        return 2;
    }
    return null;
  }

  Widget _buildRoleLogoAndSignature(String userRole, BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final branding = authProvider.branding;
    final logoUrl = branding['logoUrl'] as String?;
    final logoScale = (branding['logoScale'] as num?)?.toDouble() ?? 1;
    final logoOffsetX = (branding['logoOffsetX'] as num?)?.toDouble() ?? 0;
    final logoOffsetY = (branding['logoOffsetY'] as num?)?.toDouble() ?? 0;
    final rawBrandName =
        authProvider.gymName ?? branding['gymName']?.toString() ?? '';
    final normalizedBrandName = rawBrandName.trim();
    final brandName =
        normalizedBrandName.isEmpty ||
            normalizedBrandName.toLowerCase() == 'null'
        ? 'GymMate'
        : normalizedBrandName;
    String asset = '';
    String label = '';
    switch (userRole) {
      case 'admin':
        asset = 'assets/logos/superadmin_logo.png';
        label = 'Superadmin';
        break;
      case 'owner':
        asset = 'assets/logos/owner_logo.png';
        label = 'Owner';
        break;
      case 'trainer':
        asset = 'assets/logos/trainer_logo.png';
        label = 'Trainer';
        break;
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
    final textColor = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    final hasGymLogo = logoUrl != null && logoUrl.isNotEmpty;
    final hasAsset = asset.isNotEmpty;

    if (hasGymLogo) {
      return Row(
        children: [
          SizedBox(
            height: 56,
            width: 56,
            child: BrandingLogoFrame(
              source: logoUrl,
              size: 56,
              scale: logoScale,
              offsetX: logoOffsetX,
              offsetY: logoOffsetY,
              borderRadius: BorderRadius.circular(12),
              fallback: hasAsset
                  ? Image.asset(asset, fit: BoxFit.contain)
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              brandName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      );
    }

    if (hasAsset) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1D1A12)
                    : Colors.white,
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF5B4C26)
                      : const Color(0xFFE7D6A7),
                ),
              ),
              padding: const EdgeInsets.all(5),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brandName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  _RoleSignatureChip(
                    label: label == 'Superadmin' ? 'Admin' : label,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF241F16)
                        : const Color(0xFFFFF4E7),
                    borderColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF5B4C26)
                        : const Color(0xFFE9D2A4),
                    textColor: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.82)
                        : Colors.black87.withValues(alpha: 0.72),
                    iconColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void setTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userRole =
        normalizeRole(
          authProvider.userData?['role'] as String? ?? authProvider.userRole,
        ) ??
        '';
    final isGymMember = isMemberRole(userRole);
    final isAdmin = isAdminRole(userRole);
    final hasPassword = authProvider.userData?['hasPassword'] == true;

    if (authProvider.mustSetPassword || !hasPassword) {
      return const RequiredPasswordSetupPage();
    }

    // Check for onboarding status for gym members
    if (isGymMember && !authProvider.hasCompletedOnboarding) {
      return const OnboardingFlow();
    }

    final destinations = <_NavDestination>[
      _NavDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        page: isGymMember
            ? const GymMemberDashboardPage()
            : isTrainerRole(userRole)
            ? const GymTrainerDashboardPage()
            : const AdminDashboardPage(),
      ),
    ];

    // Add Invites tab for superadmin only
    if (isAdmin) {
      destinations.add(
        const _NavDestination(
          label: 'Invites',
          icon: Icons.group_add_rounded,
          page: InviteCodeListPage(),
        ),
      );
    }

    if (isTrainerRole(userRole)) {
      destinations.add(
        const _NavDestination(
          label: 'Clients',
          icon: Icons.people_alt_outlined,
          page: TrainerClientsPage(),
        ),
      );
      destinations.add(
        const _NavDestination(
          label: 'Messages',
          icon: Icons.forum_outlined,
          page: TrainerMessagesPage(),
        ),
      );
    }

    // Add member destinations
    if (isGymMember) {
      destinations.add(
        const _NavDestination(
          label: 'Plan',
          icon: Icons.calendar_today_rounded,
          page: PlanPage(),
        ),
      );
      destinations.add(
        const _NavDestination(
          label: 'Membership',
          icon: Icons.card_membership_rounded,
          page: MemberMembershipPage(),
        ),
      );
      destinations.add(
        const _NavDestination(
          label: 'Coach',
          icon: Icons.sports_gymnastics,
          page: CoachPage(),
        ),
      );
    }

    // Add Profile page for all roles
    destinations.add(
      const _NavDestination(
        label: 'Profile',
        icon: Icons.person_rounded,
        page: ProfilePage(),
      ),
    );

    // Guard: Ensure _selectedIndex is in range
    final pages = destinations.map((destination) => destination.page).toList();
    final safeIndex = (_selectedIndex < destinations.length)
        ? _selectedIndex
        : 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        title: _buildRoleLogoAndSignature(userRole, context),
      ),
      body: pages[safeIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: _ModernBottomNavigationBar(
          destinations: destinations,
          currentIndex: safeIndex,
          onTap: setTab,
        ),
      ),
    );
  }
}

class _RoleSignatureChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;

  const _RoleSignatureChip({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
  });

  IconData _chipIconForLabel() {
    switch (label.toLowerCase()) {
      case 'owner':
        return Icons.workspace_premium_outlined;
      case 'trainer':
        return Icons.fitness_center_rounded;
      case 'member':
        return Icons.favorite_outline_rounded;
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_chipIconForLabel(), size: 13, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final Widget page;

  const _NavDestination({
    required this.label,
    required this.icon,
    required this.page,
  });
}

class _ModernBottomNavigationBar extends StatelessWidget {
  final List<_NavDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ModernBottomNavigationBar({
    required this.destinations,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shellColor = theme.colorScheme.surface.withValues(
      alpha: isDark ? 0.94 : 0.98,
    );
    final shellBorder = theme.colorScheme.outline.withValues(
      alpha: isDark ? 0.2 : 0.34,
    );
    final shadowColor = Colors.black.withValues(alpha: isDark ? 0.24 : 0.08);
    final selectedGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactNav = constraints.maxWidth < 560;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: shellBorder),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              final isSelected = index == currentIndex;
              final foreground = isSelected
                  ? AppColors.textOnAccent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.64);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Tooltip(
                    message: destination.label,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          height: 56,
                          padding: EdgeInsets.symmetric(
                            horizontal: compactNav
                                ? 0
                                : isSelected
                                ? 12
                                : 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected ? selectedGradient : null,
                            color: isSelected
                                ? null
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: isDark ? 0.14 : 0.0),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: compactNav
                              ? Center(
                                  child: Icon(
                                    destination.icon,
                                    color: foreground,
                                    size: 22,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      destination.icon,
                                      color: foreground,
                                      size: 22,
                                    ),
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      switchInCurve: Curves.easeOut,
                                      switchOutCurve: Curves.easeIn,
                                      child: isSelected
                                          ? Padding(
                                              key: ValueKey(destination.label),
                                              padding: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              child: Text(
                                                destination.label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                      color: foreground,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
