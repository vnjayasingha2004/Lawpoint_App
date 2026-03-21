import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/appointmentRepository.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/availabilitySlot.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';
import 'package:dio/dio.dart';

class BookAppointmentScreen extends StatelessWidget {
  const BookAppointmentScreen({super.key, required this.lawyer});

  final Lawyer lawyer;

  List<_AppointmentOption> _buildOptions(List<AvailabilitySlot> slots) {
    final now = DateTime.now();
    final options = <_AppointmentOption>[];

    for (final slot in slots) {
      for (int offset = 0; offset < 21; offset++) {
        final day =
            DateTime(now.year, now.month, now.day).add(Duration(days: offset));

        if (day.weekday % 7 != slot.dayOfWeek) continue;

        final startParts = slot.startTime.split(':');
        final endParts = slot.endTime.split(':');

        if (startParts.length < 2 || endParts.length < 2) continue;

        final start = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(startParts[0]),
          int.parse(startParts[1]),
        );

        final end = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(endParts[0]),
          int.parse(endParts[1]),
        );

        if (end.isAfter(now)) {
          options.add(_AppointmentOption(start: start, end: end));
        }
      }
    }

    options.sort((a, b) => a.start.compareTo(b.start));

    final seen = <String>{};
    return options.where((o) {
      final key = '${o.start.toIso8601String()}__${o.end.toIso8601String()}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  String _extractDioErrorMessage(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      final details = data['details'];

      if (details is List && details.isNotEmpty) {
        final first = details.first;

        if (first is Map && first['message'] != null) {
          return first['message'].toString();
        }

        if (first != null) {
          return first.toString();
        }
      }

      final error = data['error'];
      if (error != null && error.toString().trim().isNotEmpty) {
        return error.toString();
      }
    }

    return e.message ?? 'Booking failed.';
  }

  Future<void> _book(BuildContext context, _AppointmentOption option) async {
    try {
      await context.read<AppointmentRepository>().bookAppointment(
            lawyerId: lawyer.id,
            start: option.start,
            end: option.end,
          );
      if (!context.mounted) return;
      showAppSnack(context, 'Appointment booked successfully.');
      Navigator.of(context).pop();
    } on DioException catch (e) {
      final message = _extractDioErrorMessage(e);

      if (!context.mounted) return;
      showAppSnack(context, message, error: true);
    } catch (e) {
      if (!context.mounted) return;
      showAppSnack(context, 'Booking failed.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: FutureBuilder<List<AvailabilitySlot>>(
        future: context.read<LawyerRepository>().getAvailability(lawyer.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final options = _buildOptions(snapshot.data ?? const []);
          if (options.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.event_busy_rounded,
                title: 'No available slots',
                message:
                    'This lawyer has not published bookable availability yet.',
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: lawyer.fullName,
                subtitle:
                    'Select one of the next available slots generated from the lawyer’s weekly availability.',
                child: const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              ...options.map(
                (option) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(friendlyDate(option.start)),
                    subtitle: Text(
                      '${friendlyTime(option.start)} - ${friendlyTime(option.end)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _book(context, option),
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

class _AppointmentOption {
  final DateTime start;
  final DateTime end;

  _AppointmentOption({required this.start, required this.end});
}
