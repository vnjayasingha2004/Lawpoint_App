import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/appointmentRepository.dart';
import '../Data/repositories/lawyerRepository.dart';
import '../Models/appointment.dart';
import '../Models/lawyer.dart';
import '../Widgets/ui.dart';
import 'appointmentsScreen.dart';
import 'lawyerProfileEditScreen.dart';

class LawyerDashboardScreen extends StatelessWidget {
  const LawyerDashboardScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lawyer dashboard'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const LawyerProfileEditScreen())),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: FutureBuilder<_DashboardData>(
        future: _load(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null || data.profile == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(
                  icon: Icons.person_off_rounded,
                  title: 'Profile unavailable',
                  message: 'Could not load your lawyer profile.'),
            );
          }
          final profile = data.profile!;
          final upcoming = data.appointments
              .where((a) => a.end.isAfter(DateTime.now()))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      StatusPill(
                          profile.verified ? 'Approved' : 'Pending review',
                          color: statusColor(
                              profile.verified ? 'approved' : 'pending')),
                      if ((profile.feeLkr ?? 0) > 0)
                        StatusPill('LKR ${profile.feeLkr!.toStringAsFixed(0)}'),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: MetricTile(
                                label: 'Upcoming',
                                value: '${upcoming.length}',
                                icon: Icons.event_rounded)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: MetricTile(
                                label: 'District',
                                value: profile.district.isEmpty
                                    ? 'Unset'
                                    : profile.district,
                                icon: Icons.location_on_outlined)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!profile.verified)
                const SectionCard(
                  title: 'Verification status',
                  subtitle:
                      'Your profile remains private until admin approval. You can still complete profile data and availability.',
                  child: SizedBox.shrink(),
                ),
              if (!profile.verified) const SizedBox(height: 16),
              SectionCard(
                title: 'Upcoming consultations',
                trailing: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AppointmentsScreen())),
                  child: const Text('View all'),
                ),
                child: upcoming.isEmpty
                    ? const Text('No upcoming bookings yet.')
                    : Column(
                        children: upcoming
                            .take(4)
                            .map((item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                      Icons.video_camera_front_rounded),
                                  title: Text(friendlyDate(item.start)),
                                  subtitle: Text(
                                      '${friendlyTime(item.start)} - ${friendlyTime(item.end)}'),
                                ))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_DashboardData> _load(BuildContext context) async {
    final profile = await context.read<LawyerRepository>().getMyLawyerProfile();

    List<Appointment> appointments = const [];
    try {
      appointments =
          await context.read<AppointmentRepository>().getMyAppointments();
    } catch (_) {
      appointments = const [];
    }

    return _DashboardData(profile: profile, appointments: appointments);
  }
}

class _DashboardData {
  final Lawyer? profile;
  final List<Appointment> appointments;

  _DashboardData({required this.profile, required this.appointments});
}
