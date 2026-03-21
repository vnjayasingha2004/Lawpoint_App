import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/providers/authProvider.dart';
import '../Data/repositories/appointmentRepository.dart';
import '../Data/repositories/chatRepository.dart';
import '../Data/repositories/paymentRepository.dart';
import '../Models/appointment.dart';
import '../Models/conversation.dart';
import '../Models/user.dart';
import '../Widgets/ui.dart';
import 'chatScreen.dart';
import 'paymentCheckoutScreen.dart';
import 'paymentsScreen.dart';
import 'videoLobbyScreen.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<List<Appointment>> _future;
  bool _hintShown = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _future = _loadAppointments();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.embedded || _hintShown) return;
      _hintShown = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Swipe left on an appointment to cancel it.'),
          duration: Duration(seconds: 3),
        ),
      );
    });

    _poller = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<List<Appointment>> _loadAppointments() {
    return context.read<AppointmentRepository>().getMyAppointments();
  }

  void _refresh() {
    setState(() {
      _future = _loadAppointments();
    });
  }

  String _friendlyError(Object e, {String fallback = 'Something went wrong.'}) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        return data['error'].toString();
      }
      return e.message ?? fallback;
    }
    return fallback;
  }

  Future<void> _openChat(BuildContext context, Appointment item) async {
    final role = context.read<AuthProvider>().user?.role;
    final repo = context.read<ChatRepository>();
    Conversation convo;

    if (role == UserRole.client) {
      convo = await repo.createOrGetConversation(lawyerId: item.lawyerId);
    } else {
      convo = await repo.createOrGetConversation(clientId: item.clientId);
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: convo)),
    );

    if (!mounted) return;
    _refresh();
  }

  Future<bool> _cancelAppointment(Appointment item) async {
    try {
      await context.read<AppointmentRepository>().cancelAppointment(item.id);
      if (!mounted) return false;
      showAppSnack(context, 'Appointment cancelled.');
      _refresh();
      return true;
    } catch (e) {
      if (!mounted) return false;
      showAppSnack(
        context,
        _friendlyError(e, fallback: 'Could not cancel appointment.'),
        error: true,
      );
      return false;
    }
  }

  Future<bool> _confirmCancelDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment'),
        content: const Text('Do you want to cancel this appointment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _pay(BuildContext context, Appointment item) async {
    final amountCtl = TextEditingController(
      text: item.amount > 0 ? item.amount.toStringAsFixed(0) : '5000',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start payment'),
        content: TextField(
          controller: amountCtl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount (LKR)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final session =
          await context.read<PaymentRepository>().createCheckoutSession(
                appointmentId: item.id,
                amount: double.tryParse(amountCtl.text.trim()) ?? 0,
              );

      final checkout = session['checkout'] as Map<String, dynamic>?;
      if (checkout == null) {
        throw Exception('Checkout session was not created.');
      }

      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentCheckoutScreen(
            actionUrl: checkout['actionUrl'] as String,
            fields: Map<String, dynamic>.from(checkout['fields'] as Map),
          ),
        ),
      );

      if (!context.mounted) return;

      if (result == true) {
        showAppSnack(context, 'Payment submitted. Refreshing status...');
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentsScreen()),
        );
        if (!mounted) return;
        _refresh();
      } else {
        showAppSnack(context, 'Payment cancelled.', error: true);
      }
    } catch (e) {
      showAppSnack(
        context,
        _friendlyError(e, fallback: 'Payment failed.'),
        error: true,
      );
    }
  }

  Future<void> _openVideo(Appointment item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoLobbyScreen(appointment: item),
      ),
    );

    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointments')),
      body: FutureBuilder<List<Appointment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? const <Appointment>[];

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'No appointments yet',
                    message:
                        'Search for a lawyer and book your first consultation.',
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = items[i];
                final canSwipeCancel = item.status.toUpperCase() == 'SCHEDULED';

                return Dismissible(
                  key: ValueKey(item.id),
                  direction: canSwipeCancel
                      ? DismissDirection.endToStart
                      : DismissDirection.none,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Swipe left to cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction != DismissDirection.endToStart) return false;

                    final yes = await _confirmCancelDialog();
                    if (!yes) return false;

                    return await _cancelAppointment(item);
                  },
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  friendlyDateTime(item.start),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              StatusPill(
                                item.status,
                                color: statusColor(item.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Ends at ${friendlyTime(item.end)}'),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openChat(context, item),
                                icon: const Icon(
                                    Icons.chat_bubble_outline_rounded),
                                label: const Text('Chat'),
                              ),
                              if (role == UserRole.client &&
                                  item.status.toUpperCase() == 'SCHEDULED' &&
                                  item.paymentStatus.toUpperCase() != 'PAID')
                                OutlinedButton.icon(
                                  onPressed: () => _pay(context, item),
                                  icon: const Icon(Icons.credit_card_rounded),
                                  label: const Text('Pay'),
                                ),
                              if (item.status.toUpperCase() == 'SCHEDULED')
                                OutlinedButton.icon(
                                  onPressed: () => _openVideo(item),
                                  icon: const Icon(Icons.video_call_rounded),
                                  label: const Text('Video'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
