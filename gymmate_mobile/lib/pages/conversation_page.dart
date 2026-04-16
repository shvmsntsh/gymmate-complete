import 'package:flutter/material.dart';
import 'package:gymmate_mobile/services/messaging_service.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class ConversationPage extends StatefulWidget {
  final String conversationId;
  final String title;
  final String subtitle;

  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.title,
    required this.subtitle,
  });

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _status = 'active';
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final payload = await MessagingService.fetchConversationMessages(
        token,
        widget.conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages = (payload['messages'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _status = (payload['conversation']?['status'] ?? 'active').toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyConversationError(error.toString());
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending || _status != 'active') return;

    setState(() => _sending = true);
    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final payload = await MessagingService.sendMessage(
        token,
        widget.conversationId,
        body,
      );
      final message = Map<String, dynamic>.from(payload['message'] as Map);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _controller.clear();
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyConversationError(error.toString()))),
      );
    }
  }

  String _friendlyConversationError(String raw) {
    final message = raw.replaceFirst('Exception: ', '');
    if (message.contains('403') ||
        message.toLowerCase().contains('invalid or expired token')) {
      return 'Your session expired. Please sign in again.';
    }
    if (message.contains('Failed with status')) {
      return 'We could not load this conversation right now.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: EditorialBackdrop(
        safeBottom: false,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? EditorialSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'We could not load this conversation right now.',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(_error!, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                          EditorialPrimaryButton(
                            label: 'Retry',
                            onPressed: _loadMessages,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadMessages,
                      child: EditorialSurface(
                        padding: const EdgeInsets.all(18),
                        child: _messages.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: 320,
                                    child: _ConversationEmptyState(
                                      status: _status,
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _messages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final message = _messages[index];
                                  return _MessageBubble(message: message);
                                },
                              ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            EditorialSurface(
              radius: 28,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    enabled: _status == 'active' && !_sending,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: _status == 'active'
                          ? 'Write a message'
                          : 'This conversation is archived.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: EditorialPrimaryButton(
                      label: _status == 'active' ? 'Send reply' : 'Archived',
                      onPressed: _status == 'active' && !_sending
                          ? _sendMessage
                          : null,
                      affordance: EditorialPrimaryAffordance.arrow,
                      loading: _sending,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  final String status;

  const _ConversationEmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          status == 'active'
              ? 'Start the conversation clearly.'
              : 'This conversation has been archived.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          status == 'active'
              ? 'The first message you send here will anchor the thread and keep follow-ups in one place.'
              : 'You can still read the history here, but new replies are disabled.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = message['isMine'] == true;
    final createdAt = DateTime.tryParse(
      (message['createdAt'] ?? '').toString(),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: isMine
                ? LinearGradient(
                    colors: [
                      theme.colorScheme.secondary,
                      theme.colorScheme.primary,
                    ],
                  )
                : null,
            color: isMine
                ? null
                : theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.72,
                  ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (message['body'] ?? '').toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMine ? const Color(0xFF2C0A00) : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                createdAt == null
                    ? ''
                    : TimeOfDay.fromDateTime(
                        createdAt.toLocal(),
                      ).format(context),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isMine
                      ? const Color(0xFF2C0A00).withValues(alpha: 0.76)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
