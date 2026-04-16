import 'package:flutter/material.dart';
import 'package:gymmate_mobile/services/messaging_service.dart';
import 'package:gymmate_mobile/widgets/editorial_mobile.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class CoachPage extends StatefulWidget {
  const CoachPage({Key? key}) : super(key: key);

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _conversationId;
  String _conversationStatus = 'active';
  String _trainerName = 'Your Trainer';
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final created = await MessagingService.createConversation(
        token,
        type: 'trainer_member',
      );
      final conversation = Map<String, dynamic>.from(
        created['conversation'] as Map,
      );
      final messagesPayload = await MessagingService.fetchConversationMessages(
        token,
        conversation['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _conversationId = conversation['id'].toString();
        _conversationStatus = (conversation['status'] ?? 'active').toString();
        _trainerName = (conversation['participant']?['name'] ?? 'Your Trainer')
            .toString();
        _messages = (messagesPayload['messages'] as List<dynamic>? ?? const [])
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _conversationId == null || _sending) return;
    setState(() => _sending = true);

    try {
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      if (token == null) {
        throw Exception('Your session has expired.');
      }
      final payload = await MessagingService.sendMessage(
        token,
        _conversationId!,
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
        SnackBar(content: Text(_friendlyCoachError(error.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadConversation,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: EditorialBackdrop(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coach', style: theme.textTheme.titleLarge),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  _CoachStateCard(
                    title: _error!.contains('No trainer is assigned')
                        ? 'Your trainer conversation is not ready yet.'
                        : 'We could not open the coach conversation right now.',
                    copy: _error!.contains('No trainer is assigned')
                        ? 'Once your owner links you with a trainer, messages will appear here.'
                        : _friendlyCoachError(_error!),
                    buttonLabel: 'Retry',
                    onPressed: _loadConversation,
                  )
                else ...[
                  EditorialSurface(
                    padding: const EdgeInsets.all(16),
                    radius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const EditorialKicker('Coach'),
                                  const SizedBox(height: 8),
                                  Text(
                                    _trainerName,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                            if (_conversationStatus != 'active')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Archived',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_messages.isEmpty)
                          Text(
                            'Start with a quick update or question.',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Column(
                            children: _messages
                                .map(
                                  (message) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CoachBubble(message: message),
                                  ),
                                )
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  EditorialSurface(
                    padding: const EdgeInsets.all(14),
                    radius: 24,
                    child: Column(
                      children: [
                        TextField(
                          controller: _controller,
                          enabled: _conversationStatus == 'active' && !_sending,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _conversationStatus == 'active'
                                ? 'Write to your trainer'
                                : 'This conversation is archived.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: EditorialPrimaryButton(
                            label: _conversationStatus == 'active'
                                ? 'Send message'
                                : 'Archived',
                            onPressed:
                                _conversationStatus == 'active' && !_sending
                                ? _sendMessage
                                : null,
                            loading: _sending,
                          ),
                        ),
                      ],
                    ),
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

String _friendlyCoachError(String error) {
  final normalized = error.toLowerCase();
  if (normalized.contains('403') ||
      normalized.contains('expired token') ||
      normalized.contains('session')) {
    return 'Your session expired. Refresh and try again.';
  }
  return error;
}

class _CoachStateCard extends StatelessWidget {
  final String title;
  final String copy;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _CoachStateCard({
    required this.title,
    required this.copy,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return EditorialSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(copy, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          EditorialPrimaryButton(label: buttonLabel, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _CoachBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const _CoachBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMine = message['isMine'] == true;

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
          child: Text(
            (message['body'] ?? '').toString(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMine ? const Color(0xFF2C0A00) : null,
            ),
          ),
        ),
      ),
    );
  }
}
