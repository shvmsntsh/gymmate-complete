import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/widgets/animated_form_field.dart';
import 'package:gymmate_mobile/themes/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QuickJoinScreen extends StatefulWidget {
  final VoidCallback onBack;

  const QuickJoinScreen({Key? key, required this.onBack}) : super(key: key);

  @override
  _QuickJoinScreenState createState() => _QuickJoinScreenState();
}

class _QuickJoinScreenState extends State<QuickJoinScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _onQuickLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.quickLogin(
        _phoneController.text.trim(),
        _otpController.text.trim(),
      );
      // On success, navigation is handled by main.dart's Consumer
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              const SizedBox(height: 8),
              Text('Quick Join', style: theme.textTheme.headlineSmall),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              AnimatedFormField(
                controller: _phoneController,
                hintText: 'Phone Number (+91)',
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  // Basic validation for Indian phone numbers
                  if (!RegExp(r'^(?:\+91)?[6-9]\d{9}$').hasMatch(v)) {
                    return 'Invalid phone number';
                  }
                  return null;
                },
                index: 0,
              ),
              const SizedBox(height: 16),
              AnimatedFormField(
                controller: _otpController,
                hintText: '4-Digit OTP',
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length != 4) return 'Must be 4 digits';
                  return null;
                },
                index: 1,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : GestureDetector(
                      onTap: _onQuickLogin,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Verify & Login',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textOnAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ).animate().scaleXY(begin: 0.98, end: 1.0, duration: 200.ms, curve: Curves.easeOut),
            ],
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
        ),
      ),
    );
  }
} 