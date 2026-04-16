import 'package:flutter/material.dart';
import 'package:gymmate_mobile/pages/conversation_page.dart';
import 'package:gymmate_mobile/services/messaging_service.dart';
import 'package:gymmate_mobile/widgets/editorial_dashboard_mobile.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class TrainerMessagesPage extends StatefulWidget {
  const TrainerMessagesPage({super.key});

  @override
  State<TrainerMessagesPage> createState() => _TrainerMessagesPageState();
}

class _TrainerMessagesPageState extends State<TrainerMessagesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final conversations = await MessagingService.fetchConversations(token);
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyInboxError(error.toString());
        _loading = false;
      });
    }
  }

  String _friendlyInboxError(String raw) {
    final message = raw.replaceFirst('Exception: ', '');
    if (message.contains('403') ||
        message.toLowerCase().contains('invalid or expired token')) {
      return 'Your session expired. Please sign in again.';
    }
    if (message.contains('Failed with status')) {
      return 'We could not load messages right now.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final ownerThreads = _conversations
        .where((entry) => (entry['section'] ?? '') == 'owner')
        .toList();
    final clientThreads = _conversations
        .where((entry) => (entry['section'] ?? '') == 'clients')
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Messages', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                DashboardHeroCard(
                  eyebrow: 'Coach Inbox',
                  title: 'Owner and client replies live here.',
                  subtitle: 'Reply fast and keep coaching updates clear.',
                  metaLeft: '${clientThreads.length} client',
                  metaRight: '${ownerThreads.length} owner',
                  buttonLabel: 'Refresh messages',
                  onTap: _loadConversations,
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  DashboardSectionCard(
                    eyebrow: 'Needs Attention',
                    title: 'Messages could not be loaded right now.',
                    subtitle: _error,
                    child: EditorialPrimaryButton(
                      label: 'Retry',
                      onPressed: _loadConversations,
                    ),
                  )
                else ...[
                  _ConversationSection(
                    eyebrow: 'Clients',
                    title: clientThreads.isEmpty
                        ? 'No client threads yet.'
                        : 'Client conversations',
                    conversations: clientThreads,
                    onConversationClosed: _loadConversations,
                  ),
                  const SizedBox(height: 18),
                  _ConversationSection(
                    eyebrow: 'Owner',
                    title: ownerThreads.isEmpty
                        ? 'No owner thread yet.'
                        : 'Owner conversation',
                    conversations: ownerThreads,
                    onConversationClosed: _loadConversations,
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

class _ConversationSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Map<String, dynamic>> conversations;
  final Future<void> Function() onConversationClosed;

  const _ConversationSection({
    required this.eyebrow,
    required this.title,
    required this.conversations,
    required this.onConversationClosed,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardSectionCard(
      eyebrow: eyebrow,
      title: title,
      subtitle: conversations.isEmpty
          ? 'Once replies start, they will collect here with unread counts and latest updates.'
          : 'Open any thread to continue the conversation.',
      child: conversations.isEmpty
          ? const _EmptyThreadState()
          : Column(
              children: List.generate(conversations.length, (index) {
                final conversation = conversations[index];
                final participant = Map<String, dynamic>.from(
                  conversation['participant'] ?? {},
                );
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == conversations.length - 1 ? 0 : 12,
                  ),
                  child: DashboardListTileCard(
                    leading: const _ThreadBadge(),
                    title: (participant['name'] ?? 'Conversation').toString(),
                    subtitle:
                        (conversation['lastMessagePreview'] ??
                                'Open the thread to continue the conversation.')
                            .toString()
                            .trim()
                            .isEmpty
                        ? 'Open the thread to continue the conversation.'
                        : (conversation['lastMessagePreview'] ?? '').toString(),
                    trailingTop: '${conversation['unreadCount'] ?? 0} unread',
                    trailingBottom: ((conversation['section'] ?? '') == 'owner')
                        ? 'OWNER'
                        : 'CLIENT',
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ConversationPage(
                            conversationId: conversation['id'].toString(),
                            title: (participant['name'] ?? 'Conversation')
                                .toString(),
                            subtitle:
                                ((conversation['section'] ?? '') == 'owner')
                                ? 'Owner conversation'
                                : 'Client conversation',
                          ),
                        ),
                      );
                      await onConversationClosed();
                    },
                  ),
                );
              }),
            ),
    );
  }
}

class _EmptyThreadState extends StatelessWidget {
  const _EmptyThreadState();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Messages will appear here as soon as a client or owner conversation becomes active.',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _ThreadBadge extends StatelessWidget {
  const _ThreadBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.forum_outlined, color: theme.colorScheme.primary),
    );
  }
}
