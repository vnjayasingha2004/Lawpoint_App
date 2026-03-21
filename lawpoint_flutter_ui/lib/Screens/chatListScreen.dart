import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/appointmentRepository.dart';
import '../Data/repositories/chatRepository.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/conversation.dart';
import '../Models/lawyer.dart';
import '../Models/message.dart';
import '../Models/user.dart';
import '../Widgets/ui.dart';
import 'chatScreen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  late Future<List<Conversation>> _future;
  Timer? _poller;

  final Map<String, String> _previewOverrides = {};
  int _previewGeneration = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadConversations();

    _poller = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<List<Conversation>> _loadConversations() async {
    final items = await context.read<ChatRepository>().getMyConversations();
    _hydrateLocalPreviews(items);
    return items;
  }

  void _refresh() {
    setState(() {
      _future = _loadConversations();
    });
  }

  void _hydrateLocalPreviews(List<Conversation> items) {
    final generation = ++_previewGeneration;
    final activeIds = items.map((e) => e.id).toSet();

    _previewOverrides.removeWhere((key, _) => !activeIds.contains(key));

    for (final item in items) {
      unawaited(_loadPreviewForConversation(item, generation));
    }
  }

  Future<void> _loadPreviewForConversation(
    Conversation conversation,
    int generation,
  ) async {
    try {
      final messages =
          await context.read<ChatRepository>().getMessages(conversation.id);

      if (!mounted || generation != _previewGeneration) return;

      final preview = _buildPreviewFromMessages(messages);

      if ((_previewOverrides[conversation.id] ?? '') == preview) return;

      setState(() {
        _previewOverrides[conversation.id] = preview;
      });
    } catch (_) {
      // Keep server preview fallback if local decrypt/fetch fails.
    }
  }

  String _buildPreviewFromMessages(List<MessageItem> messages) {
    if (messages.isEmpty) return 'No messages yet';

    final last = messages.last;
    final text = last.content.trim();

    if (text.isNotEmpty) {
      return text;
    }

    return 'Attachment';
  }

  Future<List<Lawyer>> _loadLawyers() async {
    final appointments =
        await context.read<AppointmentRepository>().getMyAppointments();

    final allowedLawyerIds = appointments
        .where((a) {
          final status = a.status.toUpperCase();
          return status == 'SCHEDULED' || status == 'COMPLETED';
        })
        .map((a) => a.lawyerId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (allowedLawyerIds.isEmpty) return [];

    final lawyers = await context.read<LawyerRepository>().searchLawyers();

    final items = lawyers
        .where((l) => l.verified && allowedLawyerIds.contains(l.id))
        .toList();

    items.sort((a, b) => a.fullName.compareTo(b.fullName));
    return items;
  }

  Future<void> _openConversation(Conversation conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: conversation),
      ),
    );
    if (!mounted) return;
    _refresh();
  }

  Future<void> _startConversation() async {
    final pickedLawyer = await showModalBottomSheet<Lawyer>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FutureBuilder<List<Lawyer>>(
              future: _loadLawyers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 260,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SizedBox(
                    height: 260,
                    child: Center(
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final lawyers = snapshot.data ?? const <Lawyer>[];
                if (lawyers.isEmpty) {
                  return const SizedBox(
                    height: 260,
                    child: Center(
                      child: Text(
                        'Book an appointment first before starting chat.',
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start conversation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a lawyer you already have an appointment with.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: lawyers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final lawyer = lawyers[index];
                          final subtitleParts = <String>[
                            if (lawyer.specialisations.isNotEmpty)
                              lawyer.specialisations.join(', '),
                            if (lawyer.district.isNotEmpty) lawyer.district,
                          ];

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  lawyer.fullName.isNotEmpty
                                      ? lawyer.fullName[0].toUpperCase()
                                      : 'L',
                                ),
                              ),
                              title: Text(lawyer.fullName),
                              subtitle: Text(
                                subtitleParts.isEmpty
                                    ? 'Verified lawyer'
                                    : subtitleParts.join(' • '),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).pop(lawyer),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (pickedLawyer == null || !mounted) return;

    try {
      final convo =
          await context.read<ChatRepository>().createOrGetConversation(
                lawyerId: pickedLawyer.id,
              );
      if (!mounted) return;
      await _openConversation(convo);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canStartConversation = role == UserRole.client;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure messages'),
        actions: [
          if (canStartConversation)
            IconButton(
              onPressed: _startConversation,
              icon: const Icon(Icons.add_comment_rounded),
              tooltip: 'Start conversation',
            ),
        ],
      ),
      floatingActionButton: canStartConversation
          ? FloatingActionButton.extended(
              onPressed: _startConversation,
              icon: const Icon(Icons.chat_rounded),
              label: const Text('Start chat'),
            )
          : null,
      body: FutureBuilder<List<Conversation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const <Conversation>[];

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  EmptyStateCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No conversations yet',
                    message: canStartConversation
                        ? 'Book an appointment first, then start chat with that lawyer.'
                        : 'No conversations yet.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = items[i];
                final title = (item.title?.trim().isNotEmpty ?? false)
                    ? item.title!
                    : 'Conversation';

                final localPreview = _previewOverrides[item.id];
                final preview = (localPreview?.trim().isNotEmpty ?? false)
                    ? localPreview!
                    : (item.lastMessagePreview?.trim().isNotEmpty ?? false)
                        ? item.lastMessagePreview!
                        : 'No messages yet';

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(title.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(title),
                    subtitle: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.updatedAt == null
                        ? null
                        : Text(friendlyTime(item.updatedAt!)),
                    onTap: () => _openConversation(item),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
