import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/membership_requests_service.dart';
import '../widgets/editorial_mobile.dart';
import 'record_payment_page.dart';

class MembershipRequestsPage extends StatefulWidget {
  const MembershipRequestsPage({super.key});

  @override
  State<MembershipRequestsPage> createState() => _MembershipRequestsPageState();
}

class _MembershipRequestsPageState extends State<MembershipRequestsPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequests());
  }

  Future<void> _loadRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await MembershipRequestsService.listRequests(token);
      if (!mounted) return;
      setState(() {
        _requests = requests;
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

  Future<void> _handleRequest(
    Map<String, dynamic> request,
    String action,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    String? responseText;
    if (action == 'approve' || action == 'reject') {
      responseText = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(
              action == 'approve' ? 'Approve Request' : 'Reject Request',
            ),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: action == 'approve'
                    ? 'e.g. Payment received'
                    : 'Reason for rejection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: Text(action == 'approve' ? 'Approve' : 'Reject'),
              ),
            ],
          );
        },
      );
      if (responseText == null) return;
    }

    try {
      if (action == 'approve') {
        await MembershipRequestsService.approveRequest(
          token,
          request['id'].toString(),
          response: responseText ?? '',
        );
      } else if (action == 'reject') {
        await MembershipRequestsService.rejectRequest(
          token,
          request['id'].toString(),
          response: responseText ?? '',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Request ${action}ed.')));
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _recordPaymentForRequest(Map<String, dynamic> request) async {
    final member = request['member'] as Map<String, dynamic>?;
    if (member == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecordPaymentPage(
          memberId: member['id'].toString(),
          memberName: member['name']?.toString() ?? 'Member',
          memberEmail: member['email']?.toString(),
          preselectedRequestId: request['id']?.toString(),
          preselectedPlanName: request['targetPlan']?['name']?.toString(),
        ),
      ),
    );
    _loadRequests();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendingCount = _requests
        .where((r) => r['status'] == 'pending')
        .length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EditorialKicker('Membership'),
                const SizedBox(height: 12),
                Text('Requests', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Approve upgrades, renewals, and add-ons from your members.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _buildErrorState()
                else if (_requests.isEmpty)
                  _buildEmptyState()
                else ...[
                  if (pendingCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.pending_actions_rounded,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$pendingCount pending request${pendingCount > 1 ? 's' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...List.generate(_requests.length, (index) {
                    final request = _requests[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _requests.length - 1 ? 14 : 0,
                      ),
                      child: _RequestCard(
                        request: request,
                        onApprove: () => _handleRequest(request, 'approve'),
                        onReject: () => _handleRequest(request, 'reject'),
                        onRecordPayment: () =>
                            _recordPaymentForRequest(request),
                      ),
                    );
                  }),
                ],
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
          const EditorialSectionHeading(
            eyebrow: 'Error',
            title: 'Could not load requests.',
            subtitle: 'Check your connection and try again.',
          ),
          const SizedBox(height: 14),
          EditorialGhostButton(label: 'Retry', onPressed: _loadRequests),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialSectionHeading(
            eyebrow: 'Requests',
            title: 'No requests yet.',
            subtitle:
                'When members ask for upgrades or renewals, they appear here.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.inbox_outlined,
                color: theme.colorScheme.outline,
                size: 48,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Requests from members will show up here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRecordPayment;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
    required this.onRecordPayment,
  });

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'approved':
      case 'activated':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'payment_pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _friendlyType(String? type) {
    switch (type) {
      case 'upgrade':
        return 'Plan Upgrade';
      case 'renewal':
        return 'Renewal';
      case 'training':
        return 'Training Add-on';
      case 'diet':
        return 'Diet Add-on';
      default:
        return type?.toString() ?? 'Request';
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'upgrade':
        return Icons.upgrade_rounded;
      case 'renewal':
        return Icons.refresh_rounded;
      case 'training':
        return Icons.fitness_center_rounded;
      case 'diet':
        return Icons.restaurant_rounded;
      default:
        return Icons.request_page_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = request['status']?.toString();
    final reqType = request['requestType']?.toString();
    final member = request['member'] as Map<String, dynamic>?;
    final targetPlan = request['targetPlan'] as Map<String, dynamic>?;
    final createdAt = request['createdAt'] != null
        ? DateTime.tryParse(request['createdAt'].toString())
        : null;
    final note = request['note']?.toString();
    final isPending = status == 'pending';

    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _typeIcon(reqType),
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member?['name']?.toString() ?? 'Unknown Member',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member?['email']?.toString() ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status?.replaceAll('_', ' ').toUpperCase() ?? 'PENDING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  _typeIcon(reqType),
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friendlyType(reqType),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (targetPlan != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${targetPlan['name'] ?? 'Unknown Plan'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (createdAt != null)
                  Text(
                    '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              '"$note"',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EditorialPrimaryButton(
                    label: 'Approve',
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
          ],
          if (status == 'approved' || status == 'payment_pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: EditorialGhostButton(
                label: 'Record Payment',
                onPressed: onRecordPayment,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
