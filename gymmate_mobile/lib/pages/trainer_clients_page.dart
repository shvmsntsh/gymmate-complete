import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gymmate_mobile/api/api_config.dart';
import 'package:gymmate_mobile/pages/conversation_page.dart';
import 'package:gymmate_mobile/services/coaching_service.dart';
import 'package:gymmate_mobile/services/messaging_service.dart';
import 'package:gymmate_mobile/widgets/editorial_dashboard_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

enum ClientFilter { all, needsAttention, inactive, completedToday }

class TrainerClientsPage extends StatefulWidget {
  const TrainerClientsPage({super.key});

  @override
  State<TrainerClientsPage> createState() => _TrainerClientsPageState();
}

class _TrainerClientsPageState extends State<TrainerClientsPage> {
  bool _loading = true;
  String? _error;
  String _query = '';
  ClientFilter _filter = ClientFilter.all;
  List<Map<String, dynamic>> _clients = const [];
  bool _handledQueryClient = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final clients = await CoachingService.fetchTrainerClients(token);
      if (!mounted) return;
      setState(() {
        _clients = clients;
        _loading = false;
      });
      _maybeOpenClientFromQuery(clients);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyTrainerClientError(error.toString());
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    final query = _query.trim().toLowerCase();
    return _clients.where((client) {
      final status = (client['status'] ?? '').toString();
      final matchesFilter = switch (_filter) {
        ClientFilter.all => true,
        ClientFilter.needsAttention => status == 'needs_attention',
        ClientFilter.inactive => status == 'inactive',
        ClientFilter.completedToday => status == 'completed',
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final name = (client['name'] ?? '').toString().toLowerCase();
      final email = (client['email'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  void _maybeOpenClientFromQuery(List<Map<String, dynamic>> clients) {
    if (_handledQueryClient) return;
    final requestedId = Uri.base.queryParameters['clientId'];
    if (requestedId == null || requestedId.isEmpty) {
      _handledQueryClient = true;
      return;
    }

    final match = clients.cast<Map<String, dynamic>?>().firstWhere(
      (client) =>
          client != null &&
          ((client['memberId'] ?? client['id'])?.toString() == requestedId),
      orElse: () => null,
    );
    if (match == null) return;

    _handledQueryClient = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openClientDetail(match);
      if (mounted) {
        _loadClients();
      }
    });
  }

  Future<void> _openClientDetail(Map<String, dynamic> client) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainerClientDetailPage(
          clientId: (client['memberId'] ?? client['id']).toString(),
          fallbackName: (client['name'] ?? 'Client').toString(),
          fallbackEmail: (client['email'] ?? '').toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trainerName =
        Provider.of<AuthProvider>(context).userData?['firstName'] ??
        Provider.of<AuthProvider>(context).userName ??
        'Trainer';
    final filteredClients = _filteredClients;
    final needsAttentionCount = _clients
        .where((client) => (client['status'] ?? '') == 'needs_attention')
        .length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadClients,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clients\n$trainerName',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: 'Coach Workspace',
                  title: _clients.length == 1
                      ? '1 client is linked to you.'
                      : '${_clients.length} clients are linked to you.',
                  subtitle: 'Search, filter, and open the next follow-up.',
                  metaLeft: '${filteredClients.length} visible',
                  metaRight: '$needsAttentionCount need follow-up',
                  buttonLabel: 'Refresh clients',
                  onTap: _loadClients,
                ),
                const SizedBox(height: 18),
                _ClientSearchPanel(
                  query: _query,
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ClientFilter.values.map((filter) {
                    return _FilterChip(
                      label: switch (filter) {
                        ClientFilter.all => 'All',
                        ClientFilter.needsAttention => 'Needs follow-up',
                        ClientFilter.inactive => 'Inactive',
                        ClientFilter.completedToday => 'Completed today',
                      },
                      selected: _filter == filter,
                      onTap: () => setState(() => _filter = filter),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  DashboardSectionCard(
                    eyebrow: 'Needs Attention',
                    title: 'Clients could not be loaded right now.',
                    subtitle: _error,
                    child: EditorialPrimaryButton(
                      label: 'Retry',
                      onPressed: _loadClients,
                    ),
                  )
                else
                  DashboardSectionCard(
                    eyebrow: 'Clients',
                    title: filteredClients.isEmpty
                        ? 'No clients match this view yet.'
                        : 'Open any client to review progress and plans.',
                    subtitle: filteredClients.isEmpty
                        ? 'Try another search or filter. New assignments will show up here.'
                        : 'Simple labels keep the next action clear.',
                    child: filteredClients.isEmpty
                        ? const _ClientsEmptyState()
                        : Column(
                            children: List.generate(filteredClients.length, (
                              index,
                            ) {
                              final client = filteredClients[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == filteredClients.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: DashboardListTileCard(
                                  leading: _ClientAvatar(
                                    name: (client['name'] ?? '').toString(),
                                    email: (client['email'] ?? '').toString(),
                                  ),
                                  title: (client['name'] ?? 'Client')
                                      .toString(),
                                  subtitle: _clientSubtitle(client),
                                  trailingTop: _clientStatusLabel(client),
                                  trailingBottom:
                                      '${client['unreadMessages'] ?? 0} MSG',
                                  onTap: () async {
                                    await _openClientDetail(client);
                                    _loadClients();
                                  },
                                ),
                              );
                            }),
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

class TrainerClientDetailPage extends StatefulWidget {
  final String clientId;
  final String fallbackName;
  final String fallbackEmail;

  const TrainerClientDetailPage({
    super.key,
    required this.clientId,
    required this.fallbackName,
    required this.fallbackEmail,
  });

  @override
  State<TrainerClientDetailPage> createState() =>
      _TrainerClientDetailPageState();
}

class _TrainerClientDetailPageState extends State<TrainerClientDetailPage> {
  bool _loading = true;
  String? _error;
  bool _savingMeal = false;
  bool _savingWorkout = false;
  Map<String, dynamic>? _clientSummary;
  List<Map<String, dynamic>> _activitySeries = const [];
  Map<String, dynamic>? _mealPlan;
  Map<String, dynamic>? _workoutPlan;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final summary = await CoachingService.fetchTrainerClientSummary(
        token,
        widget.clientId,
      );
      if (!mounted) return;
      setState(() {
        _clientSummary = Map<String, dynamic>.from(summary['client'] as Map);
        _activitySeries =
            (summary['activitySeries'] as List<dynamic>? ?? const [])
                .map((entry) => Map<String, dynamic>.from(entry as Map))
                .toList();
        _mealPlan = summary['mealPlan'] is Map
            ? Map<String, dynamic>.from(summary['mealPlan'] as Map)
            : null;
        _workoutPlan = summary['workoutPlan'] is Map
            ? Map<String, dynamic>.from(summary['workoutPlan'] as Map)
            : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyTrainerClientError(error.toString());
        _loading = false;
      });
    }
  }

  Future<void> _savePlan(String type, Map<String, dynamic> plan) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() {
      if (type == 'meal') {
        _savingMeal = true;
      } else {
        _savingWorkout = true;
      }
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/plans/${widget.clientId}/$type'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(plan),
      );
      final payload = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(payload['error'] ?? 'Failed to save $type plan');
      }
      await _loadDetail();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_titleCase(type)} plan updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyTrainerClientError(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (type == 'meal') {
            _savingMeal = false;
          } else {
            _savingWorkout = false;
          }
        });
      }
    }
  }

  Future<void> _openConversation() async {
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final payload = await MessagingService.createConversation(
        token,
        type: 'trainer_member',
        memberId: widget.clientId,
      );
      final conversation = Map<String, dynamic>.from(
        payload['conversation'] as Map,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationPage(
            conversationId: conversation['id'].toString(),
            title: (_clientSummary?['name'] ?? widget.fallbackName).toString(),
            subtitle: 'Client conversation',
          ),
        ),
      );
      _loadDetail();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyTrainerClientError(error.toString()))),
      );
    }
  }

  Future<void> _openMealEditor() async {
    if (_mealPlan == null) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealPlanEditorSheet(initialPlan: _mealPlan!),
    );
    if (updated != null) {
      await _savePlan('meal', updated);
    }
  }

  Future<void> _openWorkoutEditor() async {
    if (_workoutPlan == null) return;
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkoutPlanEditorSheet(initialPlan: _workoutPlan!),
    );
    if (updated != null) {
      await _savePlan('workout', updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = _clientSummary ?? {};
    final challenge = client['challenge'] is Map
        ? Map<String, dynamic>.from(client['challenge'] as Map)
        : null;
    final activityPoints = _activitySeries
        .map(
          (entry) => DashboardBarPoint(
            label: (entry['day'] ?? '').toString(),
            value: (entry['value'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (client['name'] ?? widget.fallbackName).toString(),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  DashboardSectionCard(
                    eyebrow: 'Needs Attention',
                    title: 'Client details could not be loaded right now.',
                    subtitle: _error,
                    child: EditorialPrimaryButton(
                      label: 'Retry',
                      onPressed: _loadDetail,
                    ),
                  )
                else ...[
                  _TrainerClientFocusHero(
                    name: (client['name'] ?? widget.fallbackName).toString(),
                    email: (client['email'] ?? widget.fallbackEmail).toString(),
                    title:
                        '${(client['name'] ?? widget.fallbackName).toString()} is ready for the next step.',
                    subtitle: 'Check rhythm, update the plan, or reply fast.',
                    metaLeft: _goalLine(client),
                    metaRight:
                        '${((client['unreadMessages'] ?? 0) as num).toInt()} unread',
                    onMessage: _openConversation,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: DashboardStatPanel(
                          label: 'Today',
                          value:
                              '${(((client['todayCompletion'] ?? 0) as num).toDouble() * 100).round()}%',
                          caption: 'completion today',
                          icon: Icons.check_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DashboardStatPanel(
                          label: 'Last Activity',
                          value: _activityDate(client),
                          caption: 'most recent log',
                          icon: Icons.schedule_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (challenge != null) ...[
                    DashboardSectionCard(
                      eyebrow: 'Challenge',
                      title: (challenge['label'] ?? 'Current challenge')
                          .toString(),
                      subtitle:
                          (challenge['summary'] ??
                                  'Challenge progress will appear as this client logs activity.')
                              .toString(),
                      child: DashboardListTileCard(
                        leading: const _ActionBadge(
                          icon: Icons.flag_outlined,
                          size: 44,
                        ),
                        title: (challenge['statusLabel'] ?? 'Ready').toString(),
                        subtitle:
                            (challenge['nextStep'] ?? 'Keep today moving.')
                                .toString(),
                        trailingTop:
                            '${challenge['current'] ?? 0}/${challenge['target'] ?? 0}',
                        trailingBottom: '${challenge['progress'] ?? 0}%'
                            .toUpperCase(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  DashboardSectionCard(
                    eyebrow: 'Weekly Consistency',
                    title: 'Seven-day rhythm.',
                    subtitle:
                        'Read consistency fast and spot follow-up points.',
                    child: DashboardBarChartCard(
                      points: activityPoints,
                      summaryLeft:
                          '${((((client['todayCompletion'] ?? 0) as num).toDouble()) * 100).round()}% today',
                      summaryRight: _clientStatusLabel(client).toUpperCase(),
                      emptyTitle: 'No activity logged yet',
                      emptySubtitle:
                          'Once the client logs meals, workouts, steps, or water, the weekly trend will appear here.',
                      detailBuilder: (label, value) =>
                          '$label shows ${value.toString()}% completion for this client.',
                    ),
                  ),
                  const SizedBox(height: 18),
                  DashboardSectionCard(
                    eyebrow: 'Quick Actions',
                    title: 'Next coaching actions.',
                    child: Row(
                      children: [
                        Expanded(
                          child: _CompactActionTile(
                            icon: Icons.restaurant_menu_rounded,
                            title: 'Meal',
                            status: _savingMeal ? 'Saving' : 'Open',
                            onTap: _savingMeal ? null : _openMealEditor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CompactActionTile(
                            icon: Icons.fitness_center_rounded,
                            title: 'Workout',
                            status: _savingWorkout ? 'Saving' : 'Open',
                            onTap: _savingWorkout ? null : _openWorkoutEditor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _CompactActionTile(
                            icon: Icons.forum_outlined,
                            title: 'Message',
                            status: 'Open',
                            onTap: _openConversation,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PlanSummarySection(
                    eyebrow: 'Workout Plan',
                    title: 'Current workout structure',
                    summary: WorkoutPlanSummary.fromPlan(_workoutPlan),
                    icon: Icons.fitness_center_rounded,
                  ),
                  const SizedBox(height: 18),
                  _PlanSummarySection(
                    eyebrow: 'Meal Plan',
                    title: 'Current meal structure',
                    summary: MealPlanSummary.fromPlan(_mealPlan),
                    icon: Icons.restaurant_menu_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _friendlyTrainerClientError(String raw) {
  final message = raw.replaceFirst('Exception: ', '');
  if (message.contains('403') ||
      message.toLowerCase().contains('invalid or expired token')) {
    return 'Your session expired. Please sign in again.';
  }
  if (message.contains('Failed with status')) {
    return 'We could not load this client right now.';
  }
  return message;
}

class _ClientSearchPanel extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;

  const _ClientSearchPanel({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EditorialSurface(
      padding: const EdgeInsets.all(16),
      radius: 26,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search clients',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: () => onChanged(''),
                  icon: const Icon(Icons.close_rounded),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHigh.withValues(
            alpha: 0.42,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.secondary,
                    theme.colorScheme.primary,
                  ],
                )
              : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? const Color(0xFF2C0A00) : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ClientsEmptyState extends StatelessWidget {
  const _ClientsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Assigned clients appear here automatically. If this stays empty, the owner still needs to link clients to you.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  final String name;
  final String email;
  final double size;

  const _ClientAvatar({
    required this.name,
    required this.email,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = tokens.isEmpty
        ? (email.isEmpty ? 'C' : email.substring(0, 1).toUpperCase())
        : (tokens.first[0] + (tokens.length > 1 ? tokens[1][0] : ''))
              .toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.secondary, theme.colorScheme.primary],
        ),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TrainerClientFocusHero extends StatelessWidget {
  final String name;
  final String email;
  final String title;
  final String subtitle;
  final String metaLeft;
  final String metaRight;
  final VoidCallback onMessage;

  const _TrainerClientFocusHero({
    required this.name,
    required this.email,
    required this.title,
    required this.subtitle,
    required this.metaLeft,
    required this.metaRight,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EditorialSurface(
      padding: EdgeInsets.zero,
      radius: 30,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wideLayout = constraints.maxWidth >= 780;
              final badgeSize = wideLayout ? 82.0 : 64.0;
              final titleStyle = wideLayout
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.headlineSmall;

              final textContent = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLIENT FOCUS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(title, style: titleStyle),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _HeroMetaPill(
                        icon: Icons.fitness_center_rounded,
                        label: metaLeft,
                      ),
                      _HeroMetaPill(
                        icon: Icons.local_fire_department_outlined,
                        label: metaRight,
                      ),
                    ],
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wideLayout)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: textContent),
                        const SizedBox(width: 24),
                        _ClientAvatar(
                          name: name,
                          email: email,
                          size: badgeSize,
                        ),
                      ],
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            'CLIENT FOCUS',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        _ClientAvatar(
                          name: name,
                          email: email,
                          size: badgeSize,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(title, style: titleStyle),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        _HeroMetaPill(
                          icon: Icons.fitness_center_rounded,
                          label: metaLeft,
                        ),
                        _HeroMetaPill(
                          icon: Icons.local_fire_department_outlined,
                          label: metaRight,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  EditorialPrimaryButton(
                    label: 'Message client',
                    onPressed: onMessage,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBadge extends StatelessWidget {
  final IconData icon;
  final double size;

  const _ActionBadge({required this.icon, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: theme.colorScheme.primary),
    );
  }
}

class _CompactActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final VoidCallback? onTap;

  const _CompactActionTile({
    required this.icon,
    required this.title,
    required this.status,
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
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionBadge(icon: icon, size: 40),
            const SizedBox(height: 10),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummarySection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final dynamic summary;
  final IconData icon;

  const _PlanSummarySection({
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final groups = (summary.groups as List<PlanGroupSummary>);
    return DashboardSectionCard(
      eyebrow: eyebrow,
      title: title,
      subtitle: summary.subtitle as String,
      child: groups.isEmpty
          ? const _SimpleEmptyState()
          : Column(
              children: List.generate(groups.length, (index) {
                final group = groups[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == groups.length - 1 ? 0 : 12,
                  ),
                  child: DashboardListTileCard(
                    leading: _ActionBadge(icon: icon),
                    title: group.title,
                    subtitle: group.subtitle,
                    trailingTop: group.trailingTop,
                    trailingBottom: group.trailingBottom,
                  ),
                );
              }),
            ),
    );
  }
}

class _SimpleEmptyState extends StatelessWidget {
  const _SimpleEmptyState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'This client does not have a plan here yet.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _MealPlanEditorSheet extends StatefulWidget {
  final Map<String, dynamic> initialPlan;

  const _MealPlanEditorSheet({required this.initialPlan});

  @override
  State<_MealPlanEditorSheet> createState() => _MealPlanEditorSheetState();
}

class _MealPlanEditorSheetState extends State<_MealPlanEditorSheet> {
  late Map<String, dynamic> _plan;

  @override
  void initState() {
    super.initState();
    _plan =
        json.decode(json.encode(widget.initialPlan)) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final meals = _mapFromDynamic(_plan['meals']);
    final sheetHeight = MediaQuery.of(context).size.height * 0.84;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: sheetHeight,
        child: EditorialSurface(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update meal plan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit meal names and key nutrition values.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ...meals.entries.map((entry) {
                        final section = _mapFromDynamic(entry.value);
                        final items = _listFromDynamic(section['items']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: Text(
                              (section['name'] ?? entry.key).toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${items.length} item${items.length == 1 ? '' : 's'}',
                            ),
                            children: [
                              EditorialSurface(
                                radius: 22,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      initialValue:
                                          (section['name'] ?? entry.key)
                                              .toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Meal block',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          meals[entry.key]['name'] = value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    ...List.generate(items.length, (index) {
                                      final item = _mapFromDynamic(
                                        items[index],
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        (item['name'] ?? '')
                                                            .toString(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Item name',
                                                        ),
                                                    onChanged: (value) =>
                                                        item['name'] = value,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      items.removeAt(index);
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        (item['calories'] ??
                                                                item['cal'] ??
                                                                '')
                                                            .toString(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Calories',
                                                        ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (value) =>
                                                        item['calories'] =
                                                            double.tryParse(
                                                              value,
                                                            ) ??
                                                            0,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: _macroValue(
                                                      item,
                                                      'protein',
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Protein',
                                                        ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (value) =>
                                                        _setMacro(
                                                          item,
                                                          'protein',
                                                          double.tryParse(
                                                                value,
                                                              ) ??
                                                              0,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: _macroValue(
                                                      item,
                                                      'carbs',
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Carbs',
                                                        ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (value) =>
                                                        _setMacro(
                                                          item,
                                                          'carbs',
                                                          double.tryParse(
                                                                value,
                                                              ) ??
                                                              0,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue: _macroValue(
                                                      item,
                                                      'fats',
                                                    ),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Fats',
                                                        ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (value) =>
                                                        _setMacro(
                                                          item,
                                                          'fats',
                                                          double.tryParse(
                                                                value,
                                                              ) ??
                                                              0,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          items.add({
                                            'name': 'New item',
                                            'calories': 0,
                                            'macros': {
                                              'protein': 0,
                                              'carbs': 0,
                                              'fats': 0,
                                            },
                                          });
                                          meals[entry.key]['items'] = items;
                                        });
                                      },
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add item'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: EditorialPrimaryButton(
                  label: 'Save meal plan',
                  onPressed: () => Navigator.of(context).pop(_plan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutPlanEditorSheet extends StatefulWidget {
  final Map<String, dynamic> initialPlan;

  const _WorkoutPlanEditorSheet({required this.initialPlan});

  @override
  State<_WorkoutPlanEditorSheet> createState() =>
      _WorkoutPlanEditorSheetState();
}

class _WorkoutPlanEditorSheetState extends State<_WorkoutPlanEditorSheet> {
  late Map<String, dynamic> _plan;

  @override
  void initState() {
    super.initState();
    _plan =
        json.decode(json.encode(widget.initialPlan)) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _mapFromDynamic(_plan['exercises']);
    final sheetHeight = MediaQuery.of(context).size.height * 0.84;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: sheetHeight,
        child: EditorialSurface(
          radius: 32,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update workout plan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Edit exercises in a clean coaching form.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ...exercises.entries.map((entry) {
                        final section = _mapFromDynamic(entry.value);
                        final items = _listFromDynamic(section['items']);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: EdgeInsets.zero,
                            title: Text(
                              (section['muscleGroup'] ?? entry.key).toString(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              '${items.length} move${items.length == 1 ? '' : 's'}',
                            ),
                            children: [
                              EditorialSurface(
                                radius: 22,
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      initialValue:
                                          (section['muscleGroup'] ?? entry.key)
                                              .toString(),
                                      decoration: const InputDecoration(
                                        labelText: 'Focus area',
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          exercises[entry.key]['muscleGroup'] =
                                              value;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    ...List.generate(items.length, (index) {
                                      final item = _mapFromDynamic(
                                        items[index],
                                      );
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        (item['name'] ?? '')
                                                            .toString(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Exercise',
                                                        ),
                                                    onChanged: (value) =>
                                                        item['name'] = value,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      items.removeAt(index);
                                                    });
                                                  },
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        (item['sets'] ?? '')
                                                            .toString(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Sets',
                                                        ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (value) =>
                                                        item['sets'] = value,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    initialValue:
                                                        (item['reps'] ?? '')
                                                            .toString(),
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText: 'Reps',
                                                        ),
                                                    onChanged: (value) =>
                                                        item['reps'] = value,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          items.add({
                                            'name': 'New exercise',
                                            'sets': '3',
                                            'reps': '10',
                                          });
                                          exercises[entry.key]['items'] = items;
                                        });
                                      },
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add exercise'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: EditorialPrimaryButton(
                  label: 'Save workout plan',
                  onPressed: () => Navigator.of(context).pop(_plan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _clientSubtitle(Map<String, dynamic> client) {
  final status = _clientStatusLabel(client);
  final planTag =
      (client['hasCustomMealPlan'] == true ||
          client['hasCustomWorkoutPlan'] == true)
      ? 'Plan updated'
      : 'Default plan';
  return '$status • $planTag • ${_activityDate(client)}';
}

String _clientStatusLabel(Map<String, dynamic> client) {
  return switch ((client['status'] ?? '').toString()) {
    'completed' => 'Completed today',
    'inactive' => 'Inactive',
    'needs_attention' => 'Needs follow-up',
    _ => 'Active',
  };
}

String _goalLine(Map<String, dynamic> client) {
  final goals = client['fitnessGoals'];
  if (goals is List && goals.isNotEmpty) {
    return _titleCase(goals.first.toString());
  }
  return 'General fitness';
}

String _activityDate(Map<String, dynamic> client) {
  final lastActivity = client['lastActivity'];
  if (lastActivity is Map && lastActivity['date'] != null) {
    return lastActivity['date'].toString().substring(5);
  }
  return 'No log';
}

String _macroValue(Map<String, dynamic> item, String key) {
  final macros = _mapFromDynamic(item['macros']);
  return (macros[key] ?? 0).toString();
}

void _setMacro(Map<String, dynamic> item, String key, double value) {
  final macros = _mapFromDynamic(item['macros']);
  macros[key] = value;
  item['macros'] = macros;
}

Map<String, dynamic> _mapFromDynamic(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map(
      (key, mappedValue) => MapEntry(key.toString(), mappedValue),
    );
  }
  return {};
}

List<dynamic> _listFromDynamic(dynamic value) {
  if (value is List<dynamic>) return value;
  if (value is List) return value.toList();
  return [];
}

String _exerciseLabel(dynamic value) {
  final map = _mapFromDynamic(value);
  final name = (map['name'] ?? map['exercise'] ?? '').toString().trim();
  final sets = (map['sets'] ?? '').toString().trim();
  final reps = (map['reps'] ?? '').toString().trim();
  final fragments = <String>[if (name.isNotEmpty) name];
  if (sets.isNotEmpty || reps.isNotEmpty) {
    fragments.add(
      [
        if (sets.isNotEmpty) '$sets sets',
        if (reps.isNotEmpty) '$reps reps',
      ].join(' • '),
    );
  }
  return fragments.join(' • ');
}

String _mealLabel(dynamic value) {
  final map = _mapFromDynamic(value);
  final name = (map['name'] ?? map['item'] ?? map['title'] ?? '')
      .toString()
      .trim();
  final calories = (map['calories'] ?? map['kcal'] ?? map['cal'] ?? '')
      .toString()
      .trim();
  if (calories.isEmpty) return name;
  if (name.isEmpty) return '$calories kcal';
  return '$name • $calories kcal';
}

String _titleCase(String value) {
  if (value.trim().isEmpty) return 'Untitled';
  return value
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class WorkoutPlanSummary {
  final String subtitle;
  final List<PlanGroupSummary> groups;

  const WorkoutPlanSummary({required this.subtitle, required this.groups});

  factory WorkoutPlanSummary.fromPlan(Map<String, dynamic>? plan) {
    final exercises = _mapFromDynamic(plan?['exercises']);
    final groups = <PlanGroupSummary>[];

    exercises.forEach((key, value) {
      final section = _mapFromDynamic(value);
      final items = _listFromDynamic(section['items']);
      groups.add(
        PlanGroupSummary(
          title: _titleCase((section['muscleGroup'] ?? key).toString()),
          subtitle: items.isEmpty
              ? 'No exercises listed here yet.'
              : items
                    .take(3)
                    .map((item) => _exerciseLabel(item))
                    .where((label) => label.isNotEmpty)
                    .join(' • '),
          trailingTop: '${items.length}',
          trailingBottom: items.length == 1 ? 'EXERCISE' : 'EXERCISES',
        ),
      );
    });

    return WorkoutPlanSummary(
      subtitle: groups.isEmpty
          ? 'This client does not have a workout plan here yet.'
          : 'Each focus area shows the first exercises inside it.',
      groups: groups,
    );
  }
}

class MealPlanSummary {
  final String subtitle;
  final List<PlanGroupSummary> groups;

  const MealPlanSummary({required this.subtitle, required this.groups});

  factory MealPlanSummary.fromPlan(Map<String, dynamic>? plan) {
    final meals = _mapFromDynamic(plan?['meals']);
    final groups = <PlanGroupSummary>[];

    meals.forEach((key, value) {
      final section = _mapFromDynamic(value);
      final items = _listFromDynamic(section['items']);
      groups.add(
        PlanGroupSummary(
          title: _titleCase((section['name'] ?? key).toString()),
          subtitle: items.isEmpty
              ? 'No meal items listed here yet.'
              : items
                    .take(3)
                    .map((item) => _mealLabel(item))
                    .where((label) => label.isNotEmpty)
                    .join(' • '),
          trailingTop: '${items.length}',
          trailingBottom: items.length == 1 ? 'ITEM' : 'ITEMS',
        ),
      );
    });

    return MealPlanSummary(
      subtitle: groups.isEmpty
          ? 'This client does not have a meal plan here yet.'
          : 'Each meal block shows the first items inside it.',
      groups: groups,
    );
  }
}

class PlanGroupSummary {
  final String title;
  final String subtitle;
  final String trailingTop;
  final String trailingBottom;

  const PlanGroupSummary({
    required this.title,
    required this.subtitle,
    required this.trailingTop,
    required this.trailingBottom,
  });
}
