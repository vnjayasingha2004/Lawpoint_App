import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/lawyerRepository.dart';
import '../Models/availabilitySlot.dart';
import '../Widgets/ui.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  List<AvailabilitySlot> _slots = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slots = await context.read<LawyerRepository>().getMyAvailability();
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loading = false;
    });
  }

  Future<void> _addSlot() async {
    int day = 1;
    final startCtl = TextEditingController(text: '09:00');
    final endCtl = TextEditingController(text: '10:00');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add availability slot'),
        content: StatefulBuilder(
          builder: (context, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: day,
                items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_dayName(i)))).toList(),
                onChanged: (v) => setLocal(() => day = v ?? day),
                decoration: const InputDecoration(labelText: 'Day of week'),
              ),
              const SizedBox(height: 12),
              TextField(controller: startCtl, decoration: const InputDecoration(labelText: 'Start time (HH:mm)')),
              const SizedBox(height: 12),
              TextField(controller: endCtl, decoration: const InputDecoration(labelText: 'End time (HH:mm)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _slots = [..._slots, AvailabilitySlot(id: DateTime.now().millisecondsSinceEpoch.toString(), dayOfWeek: day, startTime: startCtl.text.trim(), endTime: endCtl.text.trim())];
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await context.read<LawyerRepository>().updateMyAvailability(_slots);
      if (!mounted) return;
      setState(() => _slots = updated);
      showAppSnack(context, 'Availability updated.');
    } catch (e) {
      showAppSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addSlot, icon: const Icon(Icons.add_rounded), label: const Text('Add slot')),
      body: _slots.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(icon: Icons.schedule_rounded, title: 'No slots yet', message: 'Add weekly time slots so clients can book consultations.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, i) => Card(
                child: ListTile(
                  title: Text(_dayName(_slots[i].dayOfWeek)),
                  subtitle: Text('${_slots[i].startTime} - ${_slots[i].endTime}'),
                  trailing: IconButton(
                    onPressed: () => setState(() => _slots = [..._slots]..removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: _slots.length,
            ),
    );
  }
}

String _dayName(int value) {
  const names = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  if (value < 0 || value > 6) return 'Unknown';
  return names[value];
}
