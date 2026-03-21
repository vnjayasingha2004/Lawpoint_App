import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Data/repositories/videoRepository.dart';
import '../Models/appointment.dart';
import '../Models/video_session.dart';
import '../Widgets/ui.dart';
import 'videoCallScreen.dart';

class VideoLobbyScreen extends StatelessWidget {
  const VideoLobbyScreen({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video consultation')),
      body: FutureBuilder<VideoSession>(
        future: context.read<VideoRepository>().getSession(appointment.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.video_call_rounded,
                title: 'Could not open session',
                message: snapshot.error.toString(),
              ),
            );
          }

          final session = snapshot.data;
          if (session == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: EmptyStateCard(
                icon: Icons.video_call_rounded,
                title: 'Session unavailable',
                message: 'No video session was returned for this appointment.',
              ),
            );
          }

          final statusLabel = session.canJoinNow
              ? 'Ready'
              : session.state == 'BEFORE_WINDOW'
                  ? 'Scheduled'
                  : 'Expired';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Video session',
                subtitle: session.message,
                trailing: StatusPill(
                  statusLabel,
                  color: statusColor(
                    session.canJoinNow
                        ? 'approved'
                        : session.state == 'BEFORE_WINDOW'
                            ? 'scheduled'
                            : 'cancelled',
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Room: ${session.roomName}'),
                    const SizedBox(height: 8),
                    Text(
                      'Allowed from: ${session.allowedFrom == null ? 'N/A' : friendlyDateTime(session.allowedFrom!)}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allowed until: ${session.allowedUntil == null ? 'N/A' : friendlyDateTime(session.allowedUntil!)}',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.video_call_rounded),
                        label: Text(
                          session.canJoinNow
                              ? 'Join video now'
                              : session.state == 'BEFORE_WINDOW'
                                  ? 'Wait for session window'
                                  : 'Session expired',
                        ),
                        onPressed: session.canJoinNow &&
                                (session.socketToken?.isNotEmpty ?? false)
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => VideoCallScreen(
                                      session: session,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
