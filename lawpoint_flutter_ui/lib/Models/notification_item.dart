class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.readAt,
    required this.data,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    Map<String, dynamic> parseMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) {
        return v.map((key, value) => MapEntry(key.toString(), value));
      }
      return <String, dynamic>{};
    }

    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      isRead: (json['isRead'] ?? json['is_read'] ?? false) == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      readAt: parseNullableDate(json['readAt'] ?? json['read_at']),
      data: parseMap(json['data']),
    );
  }

  // compatibility getters so old UI code still works
  Map<String, dynamic> get payload => data;
  String get status => isRead ? 'read' : 'unread';
  String get message => body;
}
