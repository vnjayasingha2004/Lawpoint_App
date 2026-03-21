import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/caseRepository.dart';
import '../Data/repositories/chatRepository.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';
import 'bookAppointmentScreen.dart';
import 'chatScreen.dart';

class LawyerProfileScreen extends StatelessWidget {
  const LawyerProfileScreen({super.key, required this.lawyerId});

  final String lawyerId;

  Future<void> _openChat(BuildContext context) async {
    try {
      final conversation = await context.read<ChatRepository>().createOrGetConversation(lawyerId: lawyerId);
      if (!context.mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)));
    } catch (e) {
      showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _createCase(BuildContext context) async {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Case title')),
            const SizedBox(height: 12),
            TextField(controller: descCtl, decoration: const InputDecoration(labelText: 'Short description'), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (created != true) return;
    try {
      await context.read<CaseRepository>().createCase(
            lawyerId: lawyerId,
            title: titleCtl.text.trim().isEmpty ? 'New case' : titleCtl.text.trim(),
            description: descCtl.text.trim(),
          );
      if (!context.mounted) return;
      showAppSnack(context, 'Case created successfully.');
    } catch (e) {
      showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lawyer profile')),
      body: FutureBuilder<Lawyer?>(
        future: context.read<LawyerRepository>().getLawyerById(lawyerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lawyer = snapshot.data;
          if (lawyer == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(icon: Icons.person_off_rounded, title: 'Lawyer not found', message: 'This profile is unavailable or not yet approved.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 28, child: Text(lawyer.fullName.isNotEmpty ? lawyer.fullName[0] : '?')),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lawyer.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                StatusPill(lawyer.verified ? 'Verified' : 'Pending', color: statusColor(lawyer.verified ? 'approved' : 'pending')),
                                if ((lawyer.feeLkr ?? 0) > 0) StatusPill('LKR ${lawyer.feeLkr!.toStringAsFixed(0)}'),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(lawyer.bio?.isNotEmpty == true ? lawyer.bio! : 'No biography added yet.'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('District: ${lawyer.district.isEmpty ? 'Not provided' : lawyer.district}'),
                    const SizedBox(height: 8),
                    Text('Languages: ${lawyer.languages.isEmpty ? 'Not provided' : lawyer.languages.join(', ')}'),
                    const SizedBox(height: 8),
                    Text('Practice areas: ${lawyer.specialisations.isEmpty ? 'Not provided' : lawyer.specialisations.join(', ')}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookAppointmentScreen(lawyer: lawyer))),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Book appointment'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Open secure chat'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _createCase(context),
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Create case with this lawyer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
