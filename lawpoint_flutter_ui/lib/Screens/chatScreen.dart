import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/chatRepository.dart';
import '../Models/conversation.dart';
import '../Models/message.dart';
import '../Widgets/ui.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation});

  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _message = TextEditingController();
  bool _sending = false;

  late Future<List<MessageItem>> _future;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _future = _loadMessages();

    _poller = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      _refreshMessages();
    });
  }

  Future<List<MessageItem>> _loadMessages() {
    return context.read<ChatRepository>().getMessages(widget.conversation.id);
  }

  void _refreshMessages() {
    setState(() {
      _future = _loadMessages();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    try {
      await context.read<ChatRepository>().sendMessage(
            conversationId: widget.conversation.id,
            textOrCiphertext: text,
          );

      _message.clear();

      if (mounted) {
        _refreshMessages();
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title ?? 'Conversation'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<MessageItem>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? const <MessageItem>[];

                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyStateCard(
                      icon: Icons.mark_chat_unread_outlined,
                      title: 'No messages yet',
                      message: 'Send the first secure message.',
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshMessages(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final msg = items[i];
                      final mine = msg.senderId == currentUserId;

                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.content),
                              const SizedBox(height: 6),
                              Text(
                                friendlyTime(msg.sentAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(hintText: 'Type a message'),
                      onSubmitted: (_) {
                        if (!_sending) _send();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_sending ? 'Sending...' : 'Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
