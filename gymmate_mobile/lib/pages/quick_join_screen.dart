import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/utils/auth_input.dart';
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
  final _accessCodeController = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _canSubmit =>
      canonicalIndianPhone(_phoneController.text) != null &&
      _accessCodeController.text.trim().isNotEmpty &&
      !_loading;

  Future<void> _onQuickLogin() async {
    final phone = canonicalIndianPhone(_phoneController.text);
    if (phone == null) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    final accessCode = _accessCodeController.text.trim();
    if (accessCode.isEmpty) {
      setState(() => _error = 'Enter your invite code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.quickLogin(phone, accessCode);
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
    _accessCodeController.dispose();
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
                const PhaseOneBadge(label: 'First-time invite access'),
                const SizedBox(height: 18),
                const PhaseOneSectionTitle(
                  eyebrow: 'Invite Access',
                  title: 'Claim your first gym session.',
                  subtitle:
                      'Use the number your gym has on file and the invite code they shared with you.',
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  PhaseOneStatusBanner(message: _error!),
                  const SizedBox(height: 18),
                ],
                AnimatedFormField(
                  controller: _phoneController,
                  hintText: 'Phone number',
                  keyboardType: TextInputType.phone,
                  validator: validatePhone,
                  onChanged: (_) => setState(() => _error = null),
                  index: 0,
                ),
                const SizedBox(height: 14),
                AnimatedFormField(
                  controller: _accessCodeController,
                  hintText: 'Invite / Access Code',
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Invite code is required';
                    }
                    return v.trim().length >= 4 ? null : 'Enter invite code';
                  },
                  onChanged: (_) => setState(() => _error = null),
                  showValidationIcon: false,
                  index: 1,
                ),
                const SizedBox(height: 8),
                Text(
                  'Best for members and trainers using their invite for the first time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 22),
                PhaseOnePrimaryButton(
                  label: 'Claim Invite',
                  onTap: _canSubmit ? _onQuickLogin : null,
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
