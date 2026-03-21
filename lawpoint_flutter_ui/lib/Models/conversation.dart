class Conversation {
  final String id;
  final String clientId;
  final String lawyerId;
  final String? title;
  final String? lastMessagePreview;
  final DateTime? updatedAt;

  const Conversation({
    required this.id,
    required this.clientId,
    required this.lawyerId,
    this.title,
    this.lastMessagePreview,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return Conversation(
      id: (json['id'] ?? json['conversation_id'] ?? '').toString(),
      clientId: (json['client_id'] ?? json['clientId'] ?? '').toString(),
      lawyerId: (json['lawyer_id'] ?? json['lawyerId'] ?? '').toString(),
      title: (json['title'] ?? json['participantName'])?.toString(),
      lastMessagePreview: (json['lastMessagePreview'] ?? json['last_message'] ?? json['lastMessage'])?.toString(),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at'] ?? json['createdAt'] ?? json['created_at']),
    );
  }
}
