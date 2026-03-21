class KnowledgeArticle {
  final String id;
  final String topic;
  final String language; // en/si/ta
  final String title;
  final String content;
  final DateTime? publishedAt;

  const KnowledgeArticle({
    required this.id,
    required this.topic,
    required this.language,
    required this.title,
    required this.content,
    this.publishedAt,
  });

  static String normalizeLanguage(dynamic value) {
    final v = (value ?? 'en').toString().trim().toLowerCase();
    if (['english', 'en'].contains(v)) return 'en';
    if (['sinhala', 'si'].contains(v)) return 'si';
    if (['tamil', 'ta'].contains(v)) return 'ta';
    return v;
  }

  factory KnowledgeArticle.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

    return KnowledgeArticle(
      id: (json['id'] ?? json['article_id'] ?? '').toString(),
      topic: (json['topic'] ?? '').toString(),
      language: normalizeLanguage(json['language']),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      publishedAt: parseDate(json['published_at'] ?? json['publishedAt']),
    );
  }
}
