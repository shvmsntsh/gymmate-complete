import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/widgets/animated_form_field.dart';
import 'package:gymmate_mobile/widgets/phase_one_shell.dart';

class QuickJoinScreen extends StatefulWidget {
  final VoidCallback onBack;

  const QuickJoinScreen({Key? key, required this.onBack}) : super(key: key);

  @override
  State<QuickJoinScreen> createState() => _QuickJoinScreenState();
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
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhaseOneTopBar(onBack: widget.onBack),
          const SizedBox(height: 22),
          PhaseOneSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhaseOneBadge(label: 'Quick Join'),
                const SizedBox(height: 18),
                const PhaseOneSectionTitle(
                  eyebrow: 'Phone Access',
                  title: 'Jump back into your gym with your phone.',
                  subtitle:
                      'Use the number your gym has on file and the 4-digit access code they shared with you.',
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  PhaseOneStatusBanner(message: _error!),
                  const SizedBox(height: 18),
                ],
                AnimatedFormField(
                  controller: _phoneController,
                  hintText: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return v.trim().length >= 8 ? null : 'Invalid number';
                  },
                  index: 0,
                ),
                const SizedBox(height: 14),
                AnimatedFormField(
                  controller: _otpController,
                  hintText: '4-Digit Access Code',
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return v.trim().length == 4 ? null : 'Must be 4 digits';
                  },
                  index: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  'Best for members and trainers who want a faster way back into their training day.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                PhaseOnePrimaryButton(
                  label: 'Enter Your Gym',
                  onTap: _onQuickLogin,
                  loading: _loading,
                ),
              ],
            ),
          ),
          const PhaseOneFooterNote(label: 'Ready when your gym is'),
        ],
      ),
    );
  }
}
