import 'package:flutter/material.dart';

import '../Widgets/ui.dart';
import 'availabilityScreen.dart';
import 'caseListScreen.dart';
import 'chatListScreen.dart';
import 'knowledgeHubScreen.dart';
import 'lawyerDashboardScreen.dart';
import 'lawyerProfileEditScreen.dart';
import 'legalLockerScreen.dart';
import 'paymentsScreen.dart';
import 'settingsScreen.dart';

class LawyerTabScreen extends StatefulWidget {
  const LawyerTabScreen({super.key});

  @override
  State<LawyerTabScreen> createState() => _LawyerTabScreenState();
}

class _LawyerTabScreenState extends State<LawyerTabScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const LawyerDashboardScreen(embedded: true),
      const AvailabilityScreen(embedded: true),
      const ChatListScreen(embedded: true),
      const LegalLockerScreen(sharedMode: true, embedded: true),
      const _LawyerMoreView(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.schedule_rounded), label: 'Availability'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.folder_shared_rounded), label: 'Shared docs'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class _LawyerMoreView extends StatelessWidget {
  const _LawyerMoreView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuTile(icon: Icons.person_rounded, title: 'Edit profile', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LawyerProfileEditScreen()))),
          _MenuTile(icon: Icons.folder_open_rounded, title: 'Case tracker', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaseListScreen()))),
          _MenuTile(icon: Icons.receipt_long_rounded, title: 'Payments & earnings', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentsScreen()))),
          _MenuTile(icon: Icons.menu_book_rounded, title: 'Knowledge hub', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KnowledgeHubScreen()))),
          _MenuTile(icon: Icons.settings_rounded, title: 'Settings', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap});

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
