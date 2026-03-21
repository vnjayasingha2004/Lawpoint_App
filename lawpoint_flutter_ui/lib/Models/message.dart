class MessageItem {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String? nonce;
  final DateTime sentAt;

  const MessageItem({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    this.nonce,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        DateTime.tryParse(v.toString()) ?? DateTime.now();

    return MessageItem(
      id: (json['id'] ?? json['message_id'] ?? '').toString(),
      conversationId:
          (json['conversation_id'] ?? json['conversationId'] ?? '').toString(),
      senderId: (json['sender_id'] ??
              json['senderId'] ??
              json['senderUserId'] ??
              json['sender_user_id'] ??
              '')
          .toString(),
      content: (json['text'] ?? json['content'] ?? json['ciphertext'] ?? '')
          .toString(),
      nonce: json['nonce']?.toString(),
      sentAt: parseDate(
        json['sent_at'] ??
            json['sentAt'] ??
            json['created_at'] ??
            json['createdAt'],
      ),
    );
  }
}
