import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/caseRepository.dart';
import '../Models/caseItem.dart';
import '../Models/user.dart';
import '../Widgets/ui.dart';
import 'caseDetailScreen.dart';

class CaseListScreen extends StatelessWidget {
  const CaseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    return Scaffold(
      appBar: AppBar(title: const Text('Case Tracker')),
      body: FutureBuilder<List<CaseItem>>(
        future: context.read<CaseRepository>().getMyCases(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.folder_open_rounded,
                title: 'No cases yet',
                message: role == UserRole.client
                    ? 'Create a case from a lawyer profile to start tracking updates.'
                    : 'Cases linked to your clients will appear here.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) => Card(
              child: ListTile(
                title: Text(items[i].title),
                subtitle: Text('Created ${friendlyDateTime(items[i].createdAt)}'),
                trailing: StatusPill(items[i].status, color: statusColor(items[i].status)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(item: items[i]))),
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
