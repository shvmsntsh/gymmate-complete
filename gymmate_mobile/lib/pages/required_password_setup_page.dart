import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../widgets/animated_form_field.dart';
import '../widgets/phase_one_shell.dart';

class RequiredPasswordSetupPage extends StatefulWidget {
  const RequiredPasswordSetupPage({Key? key}) : super(key: key);

  @override
  State<RequiredPasswordSetupPage> createState() =>
      _RequiredPasswordSetupPageState();
}

class _RequiredPasswordSetupPageState extends State<RequiredPasswordSetupPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().changePassword(
        currentPassword: null,
        newPassword: password,
        token: authProvider.token,
      );
      await authProvider.refreshUser();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PhaseOneScaffold(
      scrollable: true,
      child: PhaseOnePageFrame(
        maxWidth: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PhaseOneTopBar(),
            const SizedBox(height: 18),
            PhaseOneSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PhaseOneBadge(label: 'Secure Your Account'),
                  const SizedBox(height: 14),
                  const PhaseOneSectionTitle(
                    eyebrow: 'Password Required',
                    title: 'Create your password.',
                    subtitle:
                        'Your invite code worked. Set a password now so future logins use your email or phone number.',
                  ),
                  const SizedBox(height: 18),
                  if (_error != null) ...[
                    PhaseOneStatusBanner(message: _error!),
                    const SizedBox(height: 14),
                  ],
                  AnimatedFormField(
                    controller: _passwordController,
                    hintText: 'New Password',
                    isPassword: true,
                    index: 0,
                  ),
                  const SizedBox(height: 12),
                  AnimatedFormField(
                    controller: _confirmController,
                    hintText: 'Confirm New Password',
                    isPassword: true,
                    index: 1,
                  ),
                  const SizedBox(height: 18),
                  PhaseOnePrimaryButton(
                    label: 'Set Password',
                    onTap: _savePassword,
                    loading: _loading,
                  ),
                ],
              ),
            ),
            const PhaseOneFooterNote(label: 'One setup, safer access'),
          ],
        ),
      ),
    );
  }
}
