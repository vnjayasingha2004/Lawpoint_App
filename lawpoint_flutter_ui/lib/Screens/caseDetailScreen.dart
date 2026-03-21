import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/caseRepository.dart';
import '../Models/caseItem.dart';
import '../Models/caseUpdate.dart';
import '../Models/user.dart';
import '../Widgets/ui.dart';

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.item});

  final CaseItem item;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late CaseItem _caseItem;
  late Future<List<CaseUpdate>> _future;

  @override
  void initState() {
    super.initState();
    _caseItem = widget.item;
    _future = _loadUpdates();
  }

  Future<List<CaseUpdate>> _loadUpdates() {
    return context.read<CaseRepository>().getCaseUpdates(_caseItem.id);
  }

  void _refresh() {
    setState(() {
      _future = _loadUpdates();
    });
  }

  Future<void> _addUpdate() async {
    final titleCtl = TextEditingController();
    final descCtl = TextEditingController();
    DateTime? hearingDate;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add case update'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtl,
                  decoration: const InputDecoration(labelText: 'Update title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtl,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Details / note'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: hearingDate ?? DateTime.now(),
                    );
                    if (picked == null) return;
                    setLocal(() {
                      hearingDate = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        9,
                        0,
                      );
                    });
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    hearingDate == null
                        ? 'Add hearing date'
                        : 'Hearing: ${friendlyDateTime(hearingDate!)}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || titleCtl.text.trim().isEmpty) return;

    try {
      await context.read<CaseRepository>().addUpdate(
            caseId: _caseItem.id,
            title: titleCtl.text.trim(),
            description: descCtl.text.trim(),
            hearingDate: hearingDate,
          );
      if (!mounted) return;
      showAppSnack(context, 'Update posted.');
      _refresh();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _changeStatus() async {
    const statuses = ['OPEN', 'IN_PROGRESS', 'WAITING_CLIENT', 'CLOSED'];
    String selected = _caseItem.status.toUpperCase();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update case status'),
        content: StatefulBuilder(
          builder: (context, setLocal) => DropdownButtonFormField<String>(
            value: selected,
            items: statuses
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setLocal(() => selected = v ?? selected),
            decoration: const InputDecoration(labelText: 'Status'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final updated = await context.read<CaseRepository>().updateStatus(
            caseId: _caseItem.id,
            status: selected,
          );
      if (!mounted) return;
      setState(() {
        _caseItem = updated;
      });
      showAppSnack(context, 'Status updated.');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;

    return Scaffold(
      appBar: AppBar(title: Text(_caseItem.title)),
      body: FutureBuilder<List<CaseUpdate>>(
        future: _future,
        builder: (context, snapshot) {
          final updates = snapshot.data ?? const <CaseUpdate>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: _caseItem.title,
                subtitle:
                    'Created ${friendlyDateTime(_caseItem.createdAt)}${_caseItem.description.trim().isEmpty ? '' : '\n${_caseItem.description}'}',
                trailing: StatusPill(
                  _caseItem.status,
                  color: statusColor(_caseItem.status),
                ),
                child: const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              if (role == UserRole.lawyer) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addUpdate,
                      icon: const Icon(Icons.post_add_rounded),
                      label: const Text('Add update'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _changeStatus,
                      icon: const Icon(Icons.sync_alt_rounded),
                      label: const Text('Change status'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (snapshot.connectionState != ConnectionState.done)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (updates.isEmpty)
                const EmptyStateCard(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No updates yet',
                  message:
                      'Lawyer-posted progress notes and hearing dates will appear here.',
                )
              else
                ...updates.map(
                  (update) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(update.title),
                      subtitle: Text(
                        update.hearingDate == null
                            ? '${update.description.trim().isEmpty ? friendlyDateTime(update.createdAt) : '${update.description}\nPosted: ${friendlyDateTime(update.createdAt)}'}'
                            : '${update.description.trim().isEmpty ? '' : '${update.description}\n'}Hearing: ${friendlyDateTime(update.hearingDate!)}\nPosted: ${friendlyDateTime(update.createdAt)}',
                      ),
                      isThreeLine: update.hearingDate != null ||
                          update.description.trim().isNotEmpty,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
