import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/membership_plans_service.dart';
import '../widgets/editorial_mobile.dart';

class MembershipPlansPage extends StatefulWidget {
  const MembershipPlansPage({super.key});

  @override
  State<MembershipPlansPage> createState() => _MembershipPlansPageState();
}

class _MembershipPlansPageState extends State<MembershipPlansPage> {
  List<Map<String, dynamic>> _plans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlans());
  }

  Future<void> _loadPlans() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plans = await MembershipPlansService.listPlans(token);
      if (!mounted) return;
      setState(() {
        _plans = plans;
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

  Future<void> _showPlanEditor({Map<String, dynamic>? existingPlan}) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlanEditorSheet(existingPlan: existingPlan),
    );

    if (result == null || token == null) return;

    try {
      if (existingPlan != null) {
        await MembershipPlansService.updatePlan(
          token,
          planId: existingPlan['id'].toString(),
          name: result['name'],
          durationDays: result['durationDays'],
          price: result['price'],
          description: result['description'],
          includedServices: List<String>.from(result['includedServices']),
          renewalLeadDays: result['renewalLeadDays'],
          addOns: Map<String, bool>.from(result['addOns']),
          active: result['active'],
        );
      } else {
        await MembershipPlansService.createPlan(
          token,
          name: result['name'],
          durationDays: result['durationDays'],
          price: result['price'],
          description: result['description'],
          includedServices: List<String>.from(result['includedServices']),
          renewalLeadDays: result['renewalLeadDays'],
          addOns: Map<String, bool>.from(result['addOns']),
          active: result['active'],
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingPlan != null ? 'Plan updated.' : 'Plan created.',
          ),
        ),
      );
      _loadPlans();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadPlans,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const EditorialKicker('Membership'),
                          const SizedBox(height: 12),
                          Text('Plans', style: theme.textTheme.headlineMedium),
                          const SizedBox(height: 6),
                          Text(
                            'Define what members pay for and how long each plan lasts.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        onPressed: () => _showPlanEditor(),
                        icon: const Icon(Icons.add_rounded),
                        color: const Color(0xFF390C00),
                        iconSize: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _buildErrorState()
                else if (_plans.isEmpty)
                  _buildEmptyState()
                else
                  ...List.generate(_plans.length, (index) {
                    final plan = _plans[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < _plans.length - 1 ? 14 : 0,
                      ),
                      child: _PlanCard(
                        plan: plan,
                        onTap: () => _showPlanEditor(existingPlan: plan),
                        onDelete: () => _confirmDelete(plan),
                      ),
                    );
                  }),
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
            title: 'Could not load plans.',
            subtitle: 'Check your connection and try again.',
          ),
          const SizedBox(height: 14),
          EditorialGhostButton(label: 'Retry', onPressed: _loadPlans),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EditorialSectionHeading(
            eyebrow: 'Plans',
            title: 'No plans yet.',
            subtitle: 'Create your first membership plan to start selling.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: EditorialPrimaryButton(
              label: 'Create Plan',
              onPressed: () => _showPlanEditor(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> plan) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Plan'),
        content: Text(
          'Remove "${plan['name']}"? Members on this plan will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || token == null) return;

    try {
      await MembershipPlansService.deletePlan(token, plan);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan archived.')));
      _loadPlans();
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
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = plan['active'] == true;
    final price = (plan['price'] as num?)?.toDouble() ?? 0;
    final duration = plan['durationDays'] as int? ?? 0;
    final services = List<String>.from(plan['includedServices'] ?? []);
    final addOns = plan['addOns'] as Map<String, dynamic>? ?? {};

    return GestureDetector(
      onTap: onTap,
      child: EditorialSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan['name']?.toString() ?? 'Unnamed Plan',
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.grey.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Archived',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isActive ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '\u20b9${price.toStringAsFixed(0)} for $duration days',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Archive plan',
                ),
              ],
            ),
            if (plan['description']?.toString().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                plan['description'].toString(),
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (services.isNotEmpty ||
                addOns['training'] == true ||
                addOns['diet'] == true) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ...services.map((s) => _chip(context, s)),
                  if (addOns['training'] == true)
                    _chip(context, 'Personal Training'),
                  if (addOns['diet'] == true) _chip(context, 'Diet Plan'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PlanEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? existingPlan;

  const _PlanEditorSheet({this.existingPlan});

  @override
  State<_PlanEditorSheet> createState() => _PlanEditorSheetState();
}

class _PlanEditorSheetState extends State<_PlanEditorSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;
  late TextEditingController _renewalDaysController;
  late TextEditingController _serviceController;
  bool _addTraining = false;
  bool _addDiet = false;
  bool _active = true;
  List<String> _services = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    _nameController = TextEditingController(
      text: plan?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: plan?['description']?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: ((plan?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    _durationController = TextEditingController(
      text: (plan?['durationDays'] as int?)?.toString() ?? '30',
    );
    _renewalDaysController = TextEditingController(
      text: (plan?['renewalLeadDays'] as int?)?.toString() ?? '7',
    );
    _serviceController = TextEditingController();
    if (plan != null) {
      _addTraining = plan['addOns']?['training'] == true;
      _addDiet = plan['addOns']?['diet'] == true;
      _active = plan['active'] != false;
      _services = List<String>.from(plan['includedServices'] ?? []);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _renewalDaysController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  void _addService() {
    final service = _serviceController.text.trim();
    if (service.isEmpty || _services.contains(service)) return;
    setState(() {
      _services.add(service);
      _serviceController.clear();
    });
  }

  void _removeService(String service) {
    setState(() => _services.remove(service));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;
    final renewalDays = int.tryParse(_renewalDaysController.text.trim()) ?? 7;

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Plan name is required.')));
      return;
    }
    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be at least 1 day.')),
      );
      return;
    }

    setState(() => _saving = true);
    Navigator.pop(context, {
      'name': name,
      'description': _descriptionController.text.trim(),
      'price': price,
      'durationDays': duration,
      'renewalLeadDays': renewalDays,
      'includedServices': _services,
      'addOns': {'training': _addTraining, 'diet': _addDiet},
      'active': _active,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingPlan != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'Edit Plan' : 'New Plan',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _field(
                'Plan Name',
                _nameController,
                hint: 'e.g. Premium Monthly',
              ),
              const SizedBox(height: 16),
              _field(
                'Description (optional)',
                _descriptionController,
                hint: 'What members get with this plan',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'Price (\u20b9)',
                      _priceController,
                      hint: '0',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Duration (days)',
                      _durationController,
                      hint: '30',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                'Renewal Reminder (days before)',
                _renewalDaysController,
                hint: '7',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Text('Included Services', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._services.map(
                    (s) => Chip(
                      label: Text(s),
                      onDeleted: () => _removeService(s),
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _serviceController,
                      decoration: InputDecoration(
                        hintText: 'Add a service',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _addService(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addService,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Add-ons', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  FilterChip(
                    label: const Text('Personal Training'),
                    selected: _addTraining,
                    onSelected: (v) => setState(() => _addTraining = v),
                  ),
                  FilterChip(
                    label: const Text('Diet Plan'),
                    selected: _addDiet,
                    onSelected: (v) => setState(() => _addDiet = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                value: _active,
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Members can be assigned this plan'),
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : EditorialPrimaryButton(
                        label: isEditing ? 'Save Changes' : 'Create Plan',
                        onPressed: _save,
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
