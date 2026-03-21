import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/notificationRepository.dart';
import '../Models/notification_item.dart';
import '../Widgets/ui.dart';
import 'appointmentsScreen.dart';
import 'caseListScreen.dart';
import 'chatListScreen.dart';
import 'knowledgeHubScreen.dart';
import 'lawyerSearchScreen.dart';
import 'legalLockerScreen.dart';
import 'paymentsScreen.dart';
import 'settingsScreen.dart';

class ClientTabScreen extends StatefulWidget {
  const ClientTabScreen({super.key});

  @override
  State<ClientTabScreen> createState() => _ClientTabScreenState();
}

class _ClientTabScreenState extends State<ClientTabScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _ClientHomeView(),
      const LawyerSearchScreen(embedded: true),
      const AppointmentsScreen(embedded: true),
      const ChatListScreen(embedded: true),
      const _ClientMoreView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Lawyers'),
          NavigationDestination(
              icon: Icon(Icons.event_available_rounded), label: 'Appointments'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
          NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class _ClientHomeView extends StatelessWidget {
  const _ClientHomeView();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('LawPoint'),
          actions: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Welcome, ${(user != null && user.fullName.isNotEmpty) ? user.fullName : 'Client'}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        (user != null && user.email.isNotEmpty)
                            ? user.email
                            : (user?.phone ?? ''),
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(
                            child: MetricTile(
                                label: 'Account',
                                value: 'Client',
                                icon: Icons.person_rounded)),
                        SizedBox(width: 12),
                        Expanded(
                            child: MetricTile(
                                label: 'Core flow',
                                value: 'Search & book',
                                icon: Icons.calendar_month_rounded)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: [
                  _QuickCard(
                      icon: Icons.search_rounded,
                      title: 'Find lawyers',
                      subtitle: 'Browse verified profiles',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LawyerSearchScreen()))),
                  _QuickCard(
                      icon: Icons.lock_outline_rounded,
                      title: 'Legal locker',
                      subtitle: 'Upload and share files',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const LegalLockerScreen()))),
                  _QuickCard(
                      icon: Icons.folder_open_rounded,
                      title: 'My cases',
                      subtitle: 'Track lawyer updates',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CaseListScreen()))),
                  _QuickCard(
                      icon: Icons.menu_book_rounded,
                      title: 'Knowledge hub',
                      subtitle: 'Read legal articles',
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const KnowledgeHubScreen()))),
                ],
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Recent notifications',
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const _NotificationsSheet())),
                  child: const Text('View all'),
                ),
                child: FutureBuilder<List<NotificationItem>>(
                  future: context
                      .read<NotificationRepository>()
                      .getMyNotifications(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator()));
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Text(
                          'No notifications yet. Booking, case updates, and payments will appear here.');
                    }
                    final visible = items.take(3).toList();
                    return Column(
                      children: visible
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                    child: Icon(item.status == 'unread'
                                        ? Icons.notifications_active_rounded
                                        : Icons.notifications_none_rounded)),
                                title: Text(item.type
                                    .replaceAll('.', ' ')
                                    .toUpperCase()),
                                subtitle: Text(item.payload.entries.isEmpty
                                    ? 'System update'
                                    : item.payload.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(' • ')),
                              ))
                          .toList(),
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ClientMoreView extends StatelessWidget {
  const _ClientMoreView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Legal Locker',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LegalLockerScreen()))),
          _MenuTile(
              icon: Icons.folder_open_rounded,
              title: 'Case Tracker',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CaseListScreen()))),
          _MenuTile(
              icon: Icons.menu_book_rounded,
              title: 'Knowledge Hub',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const KnowledgeHubScreen()))),
          _MenuTile(
              icon: Icons.receipt_long_rounded,
              title: 'Payments & Receipts',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaymentsScreen()))),
          _MenuTile(
              icon: Icons.settings_rounded,
              title: 'Settings',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon, color: theme.colorScheme.primary)),
            const Spacer(),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<NotificationItem>>(
        future: context.read<NotificationRepository>().getMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications',
                  message:
                      'You will see booking, payment, and case activity here.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) => Card(
              child: ListTile(
                title: Text(items[i].type.replaceAll('.', ' ')),
                subtitle: Text(
                  items[i].body.trim().isEmpty
                      ? friendlyDateTime(items[i].createdAt)
                      : '${items[i].body}\n${friendlyDateTime(items[i].createdAt)}',
                ),
                isThreeLine: items[i].body.trim().isNotEmpty,
                trailing: items[i].isRead
                    ? const StatusPill('Read')
                    : const StatusPill('Unread'),
              ),
            ),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}
