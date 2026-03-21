import 'package:dio/dio.dart';

import '../../Models/payment.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';

class PaymentRepository {
  PaymentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<PaymentItem>> getMyPayments() async {
    if (AppConfig.useMockData) return const [];

    final Response res = await _apiClient.get(ApiEndpoints.payments);
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => PaymentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createCheckoutSession({
    required String appointmentId,
    required double amount,
    String currency = 'LKR',
  }) async {
    final Response res = await _apiClient.post(
      ApiEndpoints.paymentCheckoutSession,
      data: {
        'appointmentId': appointmentId,
        'amount': amount,
        'currency': currency,
      },
    );

    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
