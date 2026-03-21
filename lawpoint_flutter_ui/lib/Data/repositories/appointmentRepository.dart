import 'package:dio/dio.dart';
import '../../Models/appointment.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';

class AppointmentRepository {
  AppointmentRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Appointment>> getMyAppointments() async {
    if (AppConfig.useMockData) {
      return [];
    }

    final Response res = await _apiClient.get(ApiEndpoints.appointments);

    final data = res.data;
    if (data is List) {
      return data
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Appointment> bookAppointment({
    required String lawyerId,
    required DateTime start,
    required DateTime end,
  }) async {
    if (AppConfig.useMockData) {
      return Appointment(
        id: 'mock_appointment',
        clientId: 'u_client',
        lawyerId: lawyerId,
        start: start,
        end: end,
        status: 'SCHEDULED',
        paymentStatus: 'PENDING',
        amount: 0,
      );
    }

    final Response res = await _apiClient.post(
      ApiEndpoints.appointments,
      data: {
        'lawyerId': lawyerId,
        'startAt': start.toIso8601String(),
        'endAt': end.toIso8601String(),
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;

    return Appointment.fromJson(item);
  }

  Future<void> cancelAppointment(String appointmentId) async {
    if (AppConfig.useMockData) return;

    await _apiClient.patch(
      '${ApiEndpoints.appointments}/$appointmentId',
      data: {'status': 'CANCELLED'},
    );
  }
}
