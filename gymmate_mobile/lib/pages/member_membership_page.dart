import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/member_membership_service.dart';
import '../utils/date_format.dart';
import '../widgets/editorial_mobile.dart';

class MemberMembershipPage extends StatefulWidget {
  const MemberMembershipPage({Key? key}) : super(key: key);

  @override
  State<MemberMembershipPage> createState() => _MemberMembershipPageState();
}

class _MemberMembershipPageState extends State<MemberMembershipPage> {
  Map<String, dynamic>? _membership;
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final membership = await MemberMembershipService.getMyMembership(token);
      final receipt = await MemberMembershipService.getMyReceipt(token);

      if (!mounted) return;
      setState(() {
        _membership = membership;
        _receipt = receipt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EditorialKicker('Membership'),
                const SizedBox(height: 12),
                Text('My Plan', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'View your membership details. Your gym team handles renewals, upgrades, add-ons, and payments.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _buildErrorState()
                else if (_membership == null)
                  _buildNoPlanState()
                else
                  _buildMembershipCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialSectionHeading(
            eyebrow: 'Error',
            title: 'Could not load membership.',
            subtitle: _error,
          ),
          const SizedBox(height: 14),
          EditorialGhostButton(label: 'Retry', onPressed: _loadData),
        ],
      ),
    );
  }

  Widget _buildNoPlanState() {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialSectionHeading(
            eyebrow: 'No Plan',
            title: 'No active membership.',
            subtitle: 'Contact your gym to get started with a membership plan.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ask your gym front desk about plans, renewals, upgrades, and payment status.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard() {
    final membership = _membership!;
    final entitlements =
        membership['entitlements'] as Map<String, dynamic>? ?? {};
    final theme = Theme.of(context);
    final receipt = _receipt;

    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      membership['templateName']?.toString() ?? 'Plan',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(
                      status: membership['status']?.toString() ?? 'inactive',
                    ),
                  ],
                ),
              ),
              if (membership['isFrozen'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'FROZEN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Valid From',
            value: membership['startDate'] != null
                ? formatDateUs(membership['startDate'])
                : 'N/A',
          ),
          _InfoRow(
            label: 'Expires',
            value: membership['endDate'] != null
                ? formatDateUs(membership['endDate'])
                : 'N/A',
          ),
          if (membership['nextRenewalDate'] != null)
            _InfoRow(
              label: 'Next Renewal',
              value: formatDateUs(membership['nextRenewalDate']),
            ),
          if ((membership['paymentReference']?.toString() ?? '').isNotEmpty)
            _InfoRow(
              label: 'Payment Ref',
              value: membership['paymentReference'].toString(),
            ),
          if (receipt != null) ...[
            const SizedBox(height: 12),
            _ReceiptPanel(
              receipt: receipt,
              link: _receiptLink(receipt),
            ),
          ],
          const SizedBox(height: 16),
          if (entitlements.isNotEmpty) ...[
            Text('Your Features', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (entitlements['gymAccess'] == true)
                  const _FeatureChip(label: 'Gym Access', enabled: true),
                if (entitlements['classAccess'] == true)
                  const _FeatureChip(label: 'Class Access', enabled: true),
                if (entitlements['trainerSupport'] == true)
                  const _FeatureChip(label: 'Trainer Support', enabled: true),
                if (entitlements['dietSupport'] == true)
                  const _FeatureChip(label: 'Diet Support', enabled: true),
                if (entitlements['biometricAccess'] == true)
                  const _FeatureChip(label: 'Biometric Access', enabled: true),
                if (entitlements['lockerAccess'] == true)
                  const _FeatureChip(label: 'Locker Access', enabled: true),
                if ((entitlements['guestPasses'] as num?)?.toInt() != null &&
                    (entitlements['guestPasses'] as num) > 0)
                  _FeatureChip(
                    label: '${entitlements['guestPasses']} Guest Passes',
                    enabled: true,
                  ),
                if (entitlements['personalTraining'] == true)
                  const _FeatureChip(label: 'Personal Training', enabled: true),
                if (entitlements['dietPlan'] == true)
                  const _FeatureChip(label: 'Diet Plan', enabled: true),
              ],
            ),
          ],
          if (membership['paymentStatus'] == 'unpaid') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Payment pending. Please complete your payment at the gym front desk.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Need renewal, upgrade, add-ons, or payment help? Visit your gym front desk. Your gym team updates your plan from their web workspace.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _receiptLink(Map<String, dynamic> receipt) {
    final path = receipt['publicPath']?.toString() ?? '';
    final token = receipt['publicToken']?.toString() ?? '';
    if (kIsWeb && path.isNotEmpty) {
      return '${Uri.base.origin}$path';
    }
    if (token.isNotEmpty) {
      return '${ApiConfig.baseUrl}/api/receipts/$token';
    }
    return path;
  }
}

class _ReceiptPanel extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final String link;

  const _ReceiptPanel({required this.receipt, required this.link});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receipt ${receipt['receiptNumber'] ?? ''}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Paid ₹${NumberFormatHelper.amount(receipt['amount'])}',
            style: theme.textTheme.bodyMedium,
          ),
          if (link.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(link, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Receipt link copied.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy receipt link'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NumberFormatHelper {
  static String amount(dynamic value) {
    final parsed = value is num ? value : num.tryParse(value?.toString() ?? '');
    return (parsed ?? 0).toStringAsFixed(2);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'active': Colors.green,
      'pending_payment': Colors.orange,
      'pending_approval': Colors.amber,
      'renewal_due': Colors.blue,
      'expired': Colors.red,
      'frozen': Colors.blue,
      'canceled': Colors.grey,
      'rejected': Colors.red,
    };
    final color = colors[status] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final bool enabled;

  const _FeatureChip({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: enabled
            ? Colors.green.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: enabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: enabled
                  ? Colors.green.shade800
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
