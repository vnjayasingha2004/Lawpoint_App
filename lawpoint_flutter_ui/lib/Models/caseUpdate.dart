class CaseUpdate {
  final String id;
  final String caseId;
  final String title;
  final String description;
  final String postedById;
  final DateTime createdAt;
  final DateTime? hearingDate;

  const CaseUpdate({
    required this.id,
    required this.caseId,
    required this.title,
    required this.description,
    required this.postedById,
    required this.createdAt,
    this.hearingDate,
  });

  String get updateText =>
      description.trim().isEmpty ? title : '$title — $description';

  factory CaseUpdate.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return CaseUpdate(
      id: (json['id'] ?? json['update_id'] ?? '').toString(),
      caseId: (json['case_id'] ?? json['caseId'] ?? '').toString(),
      title: (json['title'] ?? 'Update').toString(),
      description: (json['description'] ?? '').toString(),
      postedById: (json['postedById'] ?? json['posted_by'] ?? '').toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      hearingDate:
          parseNullableDate(json['hearing_date'] ?? json['hearingDate']),
    );
  }
}
