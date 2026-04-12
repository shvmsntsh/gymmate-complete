import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/payments_service.dart';
import '../widgets/editorial_mobile.dart';

class RecordPaymentPage extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String? memberEmail;
  final String? preselectedRequestId;
  final String? preselectedPlanName;

  const RecordPaymentPage({
    super.key,
    required this.memberId,
    required this.memberName,
    this.memberEmail,
    this.preselectedRequestId,
    this.preselectedPlanName,
  });

  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  late TextEditingController _amountController;
  late TextEditingController _referenceController;
  late TextEditingController _noteController;
  String _mode = 'cash';
  bool _activateMembership = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _referenceController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _recordPayment() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }

    setState(() => _saving = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;

    try {
      await PaymentsService.recordPayment(
        token,
        memberId: widget.memberId,
        membershipRequestId: widget.preselectedRequestId,
        amount: amount,
        mode: _mode,
        reference: _referenceController.text.trim(),
        note: _noteController.text.trim(),
        activate: _activateMembership,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _activateMembership
                ? 'Payment recorded and membership activated.'
                : 'Payment recorded successfully.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: EditorialBackdrop(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EditorialSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.person_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.memberName,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (widget.memberEmail != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.memberEmail!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.preselectedPlanName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_membership_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Plan: ${widget.preselectedPlanName}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Payment Details', style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              EditorialSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount (\u20b9)',
                        prefixText: '\u20b9 ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Payment Mode', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.money_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Cash'),
                            ],
                          ),
                          selected: _mode == 'cash',
                          onSelected: (_) => setState(() => _mode = 'cash'),
                        ),
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('UPI'),
                            ],
                          ),
                          selected: _mode == 'upi',
                          onSelected: (_) => setState(() => _mode = 'upi'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: _mode == 'upi'
                            ? 'Transaction ID (optional)'
                            : 'Reference (optional)',
                        hintText: _mode == 'upi'
                            ? 'e.g. GPay/PhonePe reference'
                            : 'e.g. Receipt number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'Any additional details about this payment',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      value: _activateMembership,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activate membership'),
                      subtitle: const Text(
                        'Mark membership as active after recording payment',
                      ),
                      onChanged: (v) => setState(() => _activateMembership = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : EditorialPrimaryButton(
                        label: 'Record Payment',
                        onPressed: _recordPayment,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
