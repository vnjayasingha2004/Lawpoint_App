import 'package:dio/dio.dart';

import '../../Models/notification_item.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';

class NotificationRepository {
  NotificationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<NotificationItem>> getMyNotifications({
    bool unreadOnly = false,
  }) async {
    if (AppConfig.useMockData) {
      return DummyData.notifications;
    }

    final Response res = await _apiClient.get(
      ApiEndpoints.notifications,
      queryParameters: {'unreadOnly': unreadOnly.toString()},
    );

    final data = res.data;

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (data is List) {
      return data
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }

  Future<void> markRead(String id) async {
    if (AppConfig.useMockData) return;

    await _apiClient.post('${ApiEndpoints.notifications}/$id/read');
  }

  Future<void> markAllRead() async {
    if (AppConfig.useMockData) return;

    await _apiClient.post('${ApiEndpoints.notifications}/read-all');
  }

  Future<void> registerDeviceToken({
    required String token,
    String? deviceOs,
  }) async {
    if (AppConfig.useMockData) return;

    await _apiClient.post(
      '${ApiEndpoints.notifications}/device-token',
      data: {
        'token': token,
        if (deviceOs != null) 'deviceOs': deviceOs,
      },
    );
  }
}
