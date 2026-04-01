import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/confetti_success.dart';
import '../widgets/editorial_mobile.dart';
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

  static const List<String> allAvatars = [
    'assets/avatars/o_m_1.png',
    'assets/avatars/t_m_1.png',
    'assets/avatars/m_m_1.png',
    'assets/avatars/m_f_1.png',
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: authProvider.userName ?? '');
    _emailController = TextEditingController(
      text: authProvider.userEmail ?? '',
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(nameError ?? emailError!)));
      return;
    }

    setState(() {
      _isSaving = true;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final authService = AuthService();
      await authService.updateProfile(name: name, email: email, token: token);
      await authProvider.refreshUser();
      setState(() => _showConfetti = true);
      await Future.delayed(const Duration(milliseconds: 1600));
      if (!mounted) return;
      setState(() => _showConfetti = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatRole(String role) {
    return role
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  void _showAvatarPicker(
    BuildContext context,
    String? currentAvatar,
    Function(String) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Theme.of(context).dialogTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your avatar', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Pick the look that feels most like your training identity.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: allAvatars
                    .map(
                      (avatar) => GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelect(avatar);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: avatar == currentAvatar
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.25,
                                    ),
                              width: avatar == currentAvatar ? 2.8 : 1.2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: AssetImage(avatar),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(AuthProvider authProvider) async {
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
      if (!mounted) return;
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GamifiedEntryScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);
    final avatarPath = authProvider.avatarPath;
    final userRole = authProvider.userRole ?? 'member';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: EditorialBackdrop(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EditorialKicker('Profile'),
                  const SizedBox(height: 18),
                  EditorialSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _showAvatarPicker(context, avatarPath, (
                                selected,
                              ) async {
                                await authProvider.setAvatarPath(selected);
                                if (mounted) {
                                  setState(() {});
                                }
                              });
                            },
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Container(
                                  width: 116,
                                  height: 116,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary,
                                      ],
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.surface,
                                    ),
                                    child: avatarPath != null
                                        ? ClipOval(
                                            child: Image.asset(
                                              avatarPath,
                                              fit: BoxFit.cover,
                                              width: 108,
                                              height: 108,
                                            ),
                                          )
                                        : Icon(
                                            Icons.person_outline_rounded,
                                            size: 54,
                                            color: theme.colorScheme.primary,
                                          ),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.secondary,
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: Color(0xFF390C00),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            authProvider.userName ?? 'GymMate Member',
                            style: theme.textTheme.headlineMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Keep your account details current so your gym, coach, and progress stay in sync.',
                            style: theme.textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _formatRole(userRole).toUpperCase(),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  EditorialSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const EditorialSectionHeading(
                          eyebrow: 'Account Details',
                          title: 'Everything your gym uses to recognize you.',
                          subtitle:
                              'Update your name or email any time. Your role stays tied to your current access.',
                        ),
                        const SizedBox(height: 22),
                        _ProfileField(
                          label: 'Full Name',
                          controller: _nameController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.name,
                        ),
                        const SizedBox(height: 16),
                        _ProfileField(
                          label: 'Email',
                          controller: _emailController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _LockedProfileField(
                          label: 'Role',
                          value: _formatRole(userRole),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: EditorialPrimaryButton(
                      label: 'Save Profile',
                      loading: _isSaving,
                      onPressed: _saveProfile,
                      trailing: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF390C00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: EditorialSecondaryButton(
                      label: 'Logout',
                      onPressed: _isSaving ? null : () => _logout(authProvider),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'GymMate keeps your training identity, gym access, and profile settings together in one place.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ConfettiSuccess(show: _showConfetti),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.56,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedProfileField extends StatelessWidget {
  final String label;
  final String value;

  const _LockedProfileField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withValues(
              alpha: 0.56,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
              Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
