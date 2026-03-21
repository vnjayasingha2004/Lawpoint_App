import 'package:dio/dio.dart';

import '../../Models/knowledgeArticle.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';

class KnowledgeRepository {
  KnowledgeRepository(this._apiClient);

  final ApiClient _apiClient;

  String _apiLanguage(String? languageCode) {
    final code = (languageCode ?? '').trim().toLowerCase();
    if (code == 'en') return 'English';
    if (code == 'si') return 'Sinhala';
    if (code == 'ta') return 'Tamil';
    return languageCode ?? '';
  }

  Future<List<KnowledgeArticle>> getArticles({
    String? query,
    String? languageCode,
  }) async {
    if (AppConfig.useMockData) {
      return DummyData.articles.where((a) {
        final matchesLang = languageCode == null ||
            languageCode.isEmpty ||
            a.language == languageCode;

        final q = (query ?? '').toLowerCase().trim();
        final matchesQuery = q.isEmpty ||
            a.title.toLowerCase().contains(q) ||
            a.topic.toLowerCase().contains(q) ||
            a.content.toLowerCase().contains(q);

        return matchesLang && matchesQuery;
      }).toList();
    }

    final Response res = await _apiClient.get(
      ApiEndpoints.knowledgeArticles,
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (languageCode != null && languageCode.isNotEmpty)
          'language': _apiLanguage(languageCode),
      },
    );

    final data = res.data;

    if (data is List) {
      return data
          .map((e) => KnowledgeArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => KnowledgeArticle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return [];
  }
}
