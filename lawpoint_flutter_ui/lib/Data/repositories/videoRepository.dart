import 'package:dio/dio.dart';

import '../../Models/video_session.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';

class VideoRepository {
  VideoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<VideoSession> getSession(String appointmentId) async {
    if (AppConfig.useMockData) {
      return VideoSession(
        sessionId: 'mock_session',
        appointmentId: appointmentId,
        provider: 'webrtc',
        roomName: 'appointment_$appointmentId',
        joinUrl: '/video/appointment_$appointmentId',
        socketPath: '/ws/video',
        socketToken: 'mock_video_token',
        allowedFrom: DateTime.now().subtract(const Duration(minutes: 10)),
        allowedUntil: DateTime.now().add(const Duration(minutes: 30)),
        canJoinNow: true,
        state: 'OPEN',
        message: 'Session ready.',
        iceServers: const <Map<String, dynamic>>[],
      );
    }

    final Response res = await _apiClient.post(
      ApiEndpoints.videoToken,
      data: {'appointmentId': appointmentId},
    );

    return VideoSession.fromJson(res.data as Map<String, dynamic>);
  }

  Future<VideoSession> createSession({
    required String appointmentId,
  }) {
    return getSession(appointmentId);
  }
}
