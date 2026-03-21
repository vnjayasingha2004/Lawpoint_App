import 'package:dio/dio.dart';

import '../../Models/caseItem.dart';
import '../../Models/caseUpdate.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';

class CaseRepository {
  CaseRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CaseItem>> getMyCases() async {
    if (AppConfig.useMockData) {
      return DummyData.cases;
    }

    final Response res = await _apiClient.get(ApiEndpoints.cases);
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => CaseItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => CaseItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<CaseUpdate>> getCaseUpdates(String caseId) async {
    if (AppConfig.useMockData) {
      return DummyData.caseUpdates[caseId] ?? [];
    }

    final Response res = await _apiClient.get(ApiEndpoints.caseUpdates(caseId));
    final data = res.data;

    if (data is List) {
      return data
          .map((e) => CaseUpdate.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => CaseUpdate.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<CaseItem> createCase({
    required String lawyerId,
    required String title,
    String description = '',
  }) async {
    final Response res = await _apiClient.post(
      ApiEndpoints.cases,
      data: {
        'lawyerId': lawyerId,
        'title': title,
        'description': description,
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;

    return CaseItem.fromJson(item);
  }

  Future<CaseUpdate> addUpdate({
    required String caseId,
    required String title,
    required String description,
    DateTime? hearingDate,
  }) async {
    final Response res = await _apiClient.post(
      ApiEndpoints.caseUpdates(caseId),
      data: {
        'title': title,
        'description': description,
        if (hearingDate != null) 'hearingDate': hearingDate.toIso8601String(),
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;

    return CaseUpdate.fromJson(item);
  }

  Future<CaseItem> updateStatus({
    required String caseId,
    required String status,
  }) async {
    final Response res = await _apiClient.patch(
      '${ApiEndpoints.cases}/$caseId',
      data: {'status': status},
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;

    return CaseItem.fromJson(item);
  }
}
