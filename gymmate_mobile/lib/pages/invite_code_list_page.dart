import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:gymmate_mobile/models/invite_code_model.dart';
import 'package:gymmate_mobile/providers/auth_provider.dart';
import 'package:gymmate_mobile/services/invite_service.dart';
import 'package:gymmate_mobile/utils/role_utils.dart';
import 'package:gymmate_mobile/widgets/editorial_dashboard_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';

class InviteCodeListPage extends StatefulWidget {
  const InviteCodeListPage({super.key});

  @override
  State<InviteCodeListPage> createState() => _InviteCodeListPageState();
}

class _InviteCodeListPageState extends State<InviteCodeListPage> {
  final InviteService _inviteService = InviteService();
  late Future<List<InviteCode>> _inviteCodesFuture;

  @override
  void initState() {
    super.initState();
    _inviteCodesFuture = Future.value([]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshList());
  }

  void _refreshList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuth || authProvider.token == null) {
      setState(() {
        _inviteCodesFuture = Future.error('Not authenticated');
      });
      return;
    }

    setState(() {
      _inviteCodesFuture = _inviteService.fetchInviteCodes(authProvider.token!);
    });
  }

  Future<void> _createInvite() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuth || authProvider.token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to create an invite.')),
      );
      return;
    }

    final normalizedRole = normalizeRole(authProvider.userRole);
    final isOwner = isOwnerRole(normalizedRole);
    final isAdmin = isAdminRole(normalizedRole);

    _InviteDraft? draft;
    if (isOwner) {
      draft = await showModalBottomSheet<_InviteDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _GenerateInviteSheet(),
      );
      if (draft == null) return;
    } else if (isAdmin) {
      draft = const _InviteDraft(role: 'gym_owner');
    }

    if (draft == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This account cannot create invites from here.'),
        ),
      );
      return;
    }

    try {
      final invite = await _inviteService.generateInviteCode(
        role: draft.role,
        name: draft.name?.trim().isEmpty == true ? null : draft.name?.trim(),
        email: draft.email?.trim().isEmpty == true ? null : draft.email?.trim(),
        phoneNumber: draft.phoneNumber?.trim().isEmpty == true
            ? null
            : draft.phoneNumber?.trim(),
        token: authProvider.token!,
      );
      _refreshList();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => _InviteCreatedSheet(invite: invite),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _copyCode(String code, {String? success}) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ?? 'Invite code copied to clipboard.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showUsedInviteDetails(InviteCode code) async {
    if (!code.used) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _UsedInviteDetailsSheet(code: code),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final normalizedRole = normalizeRole(authProvider.userRole);
    final isOwner = isOwnerRole(normalizedRole);
    final headline = isOwner
        ? 'Bring new people into your gym without friction.'
        : 'Manage invites cleanly and keep a clear record of who has joined.';
    final helper = isOwner
        ? 'Create a clean invite path, track what is still open, and see who has already joined.'
        : 'Create access codes, keep open invites easy to share, and review joined details when they are claimed.';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<List<InviteCode>>(
        future: _inviteCodesFuture,
        builder: (context, snapshot) {
          final codes = snapshot.data ?? const <InviteCode>[];
          final openInvites = codes.where((code) => !code.used).toList();
          final usedInvites = codes.where((code) => code.used).toList();

          return RefreshIndicator(
            onRefresh: () async => _refreshList(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: EditorialBackdrop(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EditorialSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INVITES',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(headline, style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 10),
                          Text(helper, style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: EditorialPrimaryButton(
                              label: 'Create Invite',
                              onPressed: _createInvite,
                              trailing: const Icon(Icons.add_rounded, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (snapshot.connectionState == ConnectionState.waiting && codes.isEmpty)
                      const DashboardSectionCard(
                        eyebrow: 'Loading',
                        title: 'Pulling your invites together.',
                        subtitle: 'Open and used codes will appear here in a moment.',
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (snapshot.hasError)
                      DashboardSectionCard(
                        eyebrow: 'Needs attention',
                        title: 'We could not load your invites right now.',
                        subtitle: '${snapshot.error}'.replaceFirst('Exception: ', ''),
                        child: SizedBox(
                          width: double.infinity,
                          child: EditorialPrimaryButton(
                            label: 'Try Again',
                            onPressed: _refreshList,
                          ),
                        ),
                      )
                    else ...[
                      _InviteSection(
                        eyebrow: 'Open invites',
                        title: '${openInvites.length} ready to share',
                        subtitle: openInvites.isEmpty
                            ? 'Create a member invite when you are ready to bring someone in.'
                            : 'Each open code is ready to send right away.',
                        emptyTitle: 'No open invites right now',
                        emptySubtitle:
                            'Create a member invite when you are ready to bring someone in.',
                        codes: openInvites,
                        onCopy: _copyCode,
                        onTapUsed: _showUsedInviteDetails,
                      ),
                      const SizedBox(height: 18),
                      _InviteSection(
                        eyebrow: 'Used invites',
                        title: '${usedInvites.length} already claimed',
                        subtitle: usedInvites.isEmpty
                            ? 'Used invites will appear here with join details once they are claimed.'
                            : 'Tap a used invite to see who joined and how far they have progressed.',
                        emptyTitle: 'No one has joined from an invite yet',
                        emptySubtitle:
                            'Used invites will appear here with join details once they are claimed.',
                        codes: usedInvites,
                        onCopy: _copyCode,
                        onTapUsed: _showUsedInviteDetails,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InviteSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final String emptyTitle;
  final String emptySubtitle;
  final List<InviteCode> codes;
  final Future<void> Function(String code, {String? success}) onCopy;
  final Future<void> Function(InviteCode code) onTapUsed;

  const _InviteSection({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.codes,
    required this.onCopy,
    required this.onTapUsed,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      child: codes.isEmpty
          ? _InviteEmptyState(title: emptyTitle, subtitle: emptySubtitle)
          : Column(
              children: [
                for (var i = 0; i < codes.length; i++) ...[
                  _InviteCard(
                    code: codes[i],
                    onCopy: onCopy,
                    onTapUsed: onTapUsed,
                  ),
                  if (i != codes.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _InviteEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _InviteEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mail_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InviteCode code;
  final Future<void> Function(String code, {String? success}) onCopy;
  final Future<void> Function(InviteCode code) onTapUsed;

  const _InviteCard({
    required this.code,
    required this.onCopy,
    required this.onTapUsed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = _roleLabel(code.role);
    final statusLabel = code.statusLabel ?? (code.used ? 'Used' : 'Open');
    final subtitle = code.used
        ? 'Claimed ${code.usedDateLabel ?? _formatDate(code.updatedAt ?? code.createdAt)}'
        : 'Created ${code.createdDateLabel ?? _formatDate(code.createdAt)}';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: code.used ? () => onTapUsed(code) : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code.code, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(label: statusLabel, used: code.used),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RolePill(label: roleLabel),
                if (code.used && (code.usedByUser?.name?.isNotEmpty == true))
                  _RolePill(label: 'Joined: ${code.usedByUser!.name!}'),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _InviteIconAction(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy invite code',
                  onPressed: () => onCopy(
                    code.code,
                    success: 'Invite code ${code.code} copied.',
                  ),
                ),
                if (code.used) ...[
                  const SizedBox(width: 12),
                  _InviteIconAction(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View joined details',
                    onPressed: () => onTapUsed(code),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateInviteSheet extends StatefulWidget {
  const _GenerateInviteSheet();

  @override
  State<_GenerateInviteSheet> createState() => _GenerateInviteSheetState();
}

class _GenerateInviteSheetState extends State<_GenerateInviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'gym_member';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _InviteDraft(
        role: _selectedRole,
        name: _nameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 24, 12, bottomInset + 12),
      child: EditorialSurface(
        radius: 30,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CREATE INVITE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bring someone in with one clean code.',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Member invites are the default here. Trainer access stays available when you need it.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                _SegmentedRolePicker(
                  value: _selectedRole,
                  onChanged: (value) => setState(() => _selectedRole = value),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name (optional)',
                    hintText: 'Aditi Rao',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    hintText: 'member@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                    hintText: '+91 9876543210',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    final name = _nameController.text.trim();
                    final email = _emailController.text.trim();
                    if (phone.isEmpty) return null;
                    if (name.isEmpty || email.isEmpty) {
                      return 'Add name and email when saving a phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Add details only if you want the join to be easier to identify later. A code can still be created without them.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: EditorialPrimaryButton(
                    label: 'Generate Invite',
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedRolePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _SegmentedRolePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleChoiceChip(
            title: 'Member',
            subtitle: 'Primary',
            selected: value == 'gym_member',
            onTap: () => onChanged('gym_member'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _RoleChoiceChip(
            title: 'Trainer',
            subtitle: 'Secondary',
            selected: value == 'gym_trainer',
            onTap: () => onChanged('gym_trainer'),
          ),
        ),
      ],
    );
  }
}

class _RoleChoiceChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChoiceChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.18),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _InviteCreatedSheet extends StatelessWidget {
  final InviteCode invite;

  const _InviteCreatedSheet({required this.invite});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = _roleLabel(invite.role).toLowerCase();
    final helper = invite.role == 'gym_trainer'
        ? 'Share this code with your trainer so they can step into the workspace quickly.'
        : 'Send this code to your new member so they can join your gym in seconds.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      child: EditorialSurface(
        radius: 30,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'INVITE READY',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text('Your $roleLabel invite is ready to send.', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(helper, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite code', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SelectableText(invite.code, style: theme.textTheme.headlineMedium),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: EditorialPrimaryButton(
                label: 'Copy Invite Code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.code));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied to clipboard.')),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsedInviteDetailsSheet extends StatelessWidget {
  final InviteCode code;

  const _UsedInviteDetailsSheet({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joined = code.usedByUser;
    final joinedLabel = code.usedDateLabel ?? _formatDate(code.updatedAt ?? code.createdAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      child: EditorialSurface(
        radius: 30,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JOIN DETAILS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text('Invite ${code.code} has been claimed.', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Here is the joined-person summary for this invite.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Role', value: _roleLabel(code.role)),
            _DetailRow(label: 'Status', value: code.statusLabel ?? 'Used'),
            _DetailRow(label: 'Joined', value: joinedLabel),
            _DetailRow(
              label: 'Name',
              value: joined?.name?.isNotEmpty == true
                  ? joined!.name!
                  : 'Not captured yet',
            ),
            _DetailRow(
              label: 'Email',
              value: joined?.email?.isNotEmpty == true
                  ? joined!.email!
                  : (code.usedBy?.isNotEmpty == true ? code.usedBy! : 'Not available'),
            ),
            if (joined?.phoneNumber?.isNotEmpty == true)
              _DetailRow(label: 'Phone', value: joined!.phoneNumber!),
            _DetailRow(
              label: 'Setup',
              value: joined == null
                  ? 'Member details are still syncing'
                  : (joined.hasCompletedOnboarding
                        ? 'Onboarding complete'
                        : 'Setup still in progress'),
            ),
            if (joined?.joinedAt != null)
              _DetailRow(
                label: 'Joined at',
                value: _formatDate(joined!.joinedAt),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final bool used;

  const _StatusPill({required this.label, required this.used});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = used ? const Color(0xFF3FCB74) : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: used ? const Color(0xFF3FCB74) : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String label;

  const _RolePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _InviteIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _InviteIconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.18),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 54,
            height: 54,
            child: Icon(icon, size: 22, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _InviteDraft {
  final String role;
  final String? name;
  final String? email;
  final String? phoneNumber;

  const _InviteDraft({
    required this.role,
    this.name,
    this.email,
    this.phoneNumber,
  });
}

String _roleLabel(String role) {
  switch (normalizeRole(role)) {
    case 'owner':
      return 'Gym owner';
    case 'trainer':
      return 'Trainer';
    case 'member':
      return 'Member';
    case 'admin':
      return 'Admin';
    default:
      return role.replaceAll('_', ' ');
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Unknown';
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
