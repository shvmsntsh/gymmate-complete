import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/animated_form_field.dart';
import '../widgets/confetti_success.dart';
import 'gamified_entry_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: authProvider.userName ?? '');
    _emailController = TextEditingController(text: authProvider.userEmail ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().length < 2) {
      return 'Name must be at least 2 characters.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || !RegExp(r'^\S+@\S+\.\S+').hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final nameError = _validateName(name);
    final emailError = _validateEmail(email);
    if (nameError != null || emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(nameError ?? emailError!)),
      );
      return;
    }
    setState(() { _isSaving = true; });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final authService = AuthService();
      await authService.updateProfile(name: name, email: email, token: token);
      await authProvider.refreshUser();
      setState(() => _showConfetti = true);
      await Future.delayed(const Duration(milliseconds: 1800));
      setState(() => _showConfetti = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  String _formatRole(String role) {
    // Convert snake_case to Title Case and remove underscores
    return role.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
  }

  static const List<String> allAvatars = [
    'assets/avatars/o_m_1.png',
    'assets/avatars/t_m_1.png',
    'assets/avatars/m_m_1.png',
    'assets/avatars/m_f_1.png',
  ];

  void _showAvatarPicker(BuildContext context, String userRole, String? currentAvatar, Function(String) onSelect) {
    // Show all avatars from the avatars folder
    const avatars = allAvatars;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose your avatar', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: avatars.map((avatar) => GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelect(avatar);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: avatar == currentAvatar ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      radius: 40,
                      backgroundImage: AssetImage(avatar),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);
    final avatarPath = authProvider.avatarPath;
    final userRole = authProvider.userRole ?? 'owner';

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // Animated Avatar with selection
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _showAvatarPicker(context, userRole, avatarPath, (selected) async {
                            await authProvider.setAvatarPath(selected);
                            setState(() {});
                          });
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.grey[850] : Colors.grey[200],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: avatarPath != null
                              ? ClipOval(
                                  child: Image.asset(
                                    avatarPath,
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 72,
                                  color: accentColor,
                                ),
                        ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.8, end: 1.0, duration: 500.ms, curve: Curves.elasticOut),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Tap avatar to change',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Animated Profile Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.primary, width: 1.2),
                      ),
                      color: theme.colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedFormField(
                              controller: _nameController,
                              hintText: 'Full Name',
                              enabled: !_isSaving,
                              index: 0,
                            ),
                            const SizedBox(height: 16),
                            AnimatedFormField(
                              controller: _emailController,
                              hintText: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isSaving,
                              index: 1,
                            ),
                            const SizedBox(height: 16),
                            AnimatedFormField(
                              controller: TextEditingController(text: _formatRole(userRole)),
                              hintText: 'Role',
                              enabled: false,
                              index: 2,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 200.ms),
                    const SizedBox(height: 24),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        onPressed: _isSaving ? null : _saveProfile,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.primary, width: 2),
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Logout'),
                                    content: const Text('Are you sure you want to logout?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Logout'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await authProvider.logout();
                                  if (context.mounted) {
                                    navigatorKey.currentState!.pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => const GamifiedEntryScreen()),
                                      (Route<dynamic> route) => false,
                                    );
                                  }
                                }
                              },
                        child: const Text('Logout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ConfettiSuccess(show: _showConfetti),
        ],
      ),
    );
  }
} 