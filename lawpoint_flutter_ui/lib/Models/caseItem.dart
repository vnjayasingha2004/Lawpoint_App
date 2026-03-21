class CaseItem {
  final String id;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String clientId;
  final String lawyerId;

  const CaseItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.clientId,
    required this.lawyerId,
  });

  factory CaseItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    return CaseItem(
      id: (json['id'] ?? json['case_id'] ?? '').toString(),
      title: (json['title'] ?? 'Case').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'OPEN').toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      lawyerId: (json['lawyer_id'] ?? json['lawyerId'] ?? '').toString(),
    );
  }
}
