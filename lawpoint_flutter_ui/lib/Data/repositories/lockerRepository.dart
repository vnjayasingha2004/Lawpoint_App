import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../Models/document.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';

class LockerRepository {
  LockerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DocumentItem>> getMyDocuments() async {
    if (AppConfig.useMockData) {
      return DummyData.documents;
    }

    final res = await _apiClient.get(ApiEndpoints.lockerDocuments);
    return _mapList(res.data);
  }

  Future<List<DocumentItem>> getSharedDocuments() async {
    if (AppConfig.useMockData) {
      return DummyData.documents.where((e) => e.shared).toList();
    }

    final res = await _apiClient.get(ApiEndpoints.sharedDocuments);
    return _mapList(res.data);
  }

  List<DocumentItem> _mapList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => DocumentItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  DocumentItem _mapItem(dynamic data) {
    if (data is Map<String, dynamic> && data['item'] is Map<String, dynamic>) {
      return DocumentItem.fromJson(data['item'] as Map<String, dynamic>);
    }
    if (data is Map<String, dynamic>) {
      return DocumentItem.fromJson(data);
    }
    throw Exception('Unexpected document response');
  }

  Future<DocumentItem> uploadDocumentFile({
    required File file,
    String classification = 'NORMAL',
    String? secretCategory,
  }) async {
    if (AppConfig.useMockData) {
      final item = DocumentItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: file.path.split('/').last,
        fileType: 'application/octet-stream',
        uploadedAt: DateTime.now(),
        shared: false,
        classification: classification,
        secretCategory: secretCategory,
        redactionStatus:
            classification.toUpperCase() == 'SECRET' ? 'READY' : 'NOT_REQUIRED',
        hasRedactedVersion: classification.toUpperCase() == 'SECRET',
        requiresPreviewBeforeShare: secretCategory == 'sri_nic',
        reviewedForShare: false,
      );
      DummyData.documents.add(item);
      return item;
    }

    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'classification': classification,
      if (secretCategory != null) 'secretCategory': secretCategory,
    });

    final res = await _apiClient.post(ApiEndpoints.lockerDocuments, data: form);
    return _mapItem(res.data);
  }

  Future<DocumentItem> uploadDocumentBytes({
    required String fileName,
    required List<int> bytes,
    String classification = 'NORMAL',
    String? secretCategory,
  }) async {
    if (AppConfig.useMockData) {
      final item = DocumentItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: fileName,
        fileType: 'application/octet-stream',
        uploadedAt: DateTime.now(),
        shared: false,
        classification: classification,
        secretCategory: secretCategory,
        redactionStatus:
            classification.toUpperCase() == 'SECRET' ? 'READY' : 'NOT_REQUIRED',
        hasRedactedVersion: classification.toUpperCase() == 'SECRET',
        requiresPreviewBeforeShare: secretCategory == 'sri_nic',
        reviewedForShare: false,
      );
      DummyData.documents.add(item);
      return item;
    }

    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'classification': classification,
      if (secretCategory != null) 'secretCategory': secretCategory,
    });

    final res = await _apiClient.post(ApiEndpoints.lockerDocuments, data: form);
    return _mapItem(res.data);
  }

  Future<Uint8List> fetchPreviewBytes(String documentId) async {
    if (AppConfig.useMockData) {
      throw Exception('Preview is not available in mock mode.');
    }

    final res =
        await _apiClient.getBytes(ApiEndpoints.previewDocument(documentId));
    return Uint8List.fromList((res.data as List).cast<int>());
  }

  Future<DocumentItem> markDocumentReviewed(String documentId) async {
    if (AppConfig.useMockData) {
      final index = DummyData.documents.indexWhere((e) => e.id == documentId);
      if (index == -1) {
        throw Exception('Document not found.');
      }

      final current = DummyData.documents[index];
      final updated = DocumentItem(
        id: current.id,
        fileName: current.fileName,
        fileType: current.fileType,
        uploadedAt: current.uploadedAt,
        shared: current.shared,
        checksum: current.checksum,
        sizeBytes: current.sizeBytes,
        downloadUrl: current.downloadUrl,
        previewUrl: current.previewUrl,
        sharedWithIds: current.sharedWithIds,
        classification: current.classification,
        secretCategory: current.secretCategory,
        redactionStatus: current.redactionStatus,
        hasRedactedVersion: current.hasRedactedVersion,
        requiresPreviewBeforeShare: current.requiresPreviewBeforeShare,
        reviewedForShare: true,
        redactionReviewedAt: DateTime.now().toIso8601String(),
      );

      DummyData.documents[index] = updated;
      return updated;
    }

    final res = await _apiClient.post(
      ApiEndpoints.markDocumentReviewed(documentId),
      data: const {},
    );

    return _mapItem(res.data);
  }

  Future<void> deleteDocument(String documentId) async {
    if (AppConfig.useMockData) {
      DummyData.documents.removeWhere((e) => e.id == documentId);
      return;
    }

    await _apiClient.delete(ApiEndpoints.deleteDocument(documentId));
  }

  Future<void> shareDocument({
    required String documentId,
    required String lawyerId,
    bool allowRiskyShare = false,
  }) async {
    if (AppConfig.useMockData) return;

    await _apiClient.post(
      ApiEndpoints.shareDocument(documentId),
      data: {
        'lawyerId': lawyerId,
        'allowRiskyShare': allowRiskyShare,
      },
    );
  }

  Future<void> revokeDocument({
    required String documentId,
    required String lawyerId,
  }) async {
    if (AppConfig.useMockData) return;
    await _apiClient.post(
      ApiEndpoints.revokeDocument(documentId),
      data: {'lawyerId': lawyerId},
    );
  }

  Future<File> downloadDocument(DocumentItem doc) async {
    if (AppConfig.useMockData) {
      throw Exception('Download is not available in mock mode.');
    }

    final tokenRes = await _apiClient.post(
      ApiEndpoints.downloadDocumentToken(doc.id),
    );

    final tokenData = (tokenRes.data is Map<String, dynamic>)
        ? tokenRes.data as Map<String, dynamic>
        : <String, dynamic>{};

    final token = tokenData['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw Exception('Download token was not returned by the server.');
    }

    final res = await _apiClient.getBytes(
      ApiEndpoints.downloadDocumentSigned(doc.id),
      queryParameters: {'token': token},
    );

    final bytes = (res.data as List).cast<int>();
    final safeName = doc.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final prefix = doc.isSecret ? 'redacted_' : '';
    final out = File('${Directory.systemTemp.path}/$prefix$safeName');
    await out.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return out;
  }
}
