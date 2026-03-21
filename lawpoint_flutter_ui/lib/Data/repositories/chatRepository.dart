import 'package:dio/dio.dart';

import '../../Models/conversation.dart';
import '../../Models/message.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../storage/dummy_data.dart';
import '../security/encryptionService.dart';
import '../storage/secureStorage.dart';

class ChatRepository {
  ChatRepository(this._apiClient);

  final ApiClient _apiClient;
  final SecureStorage _secureStorage = SecureStorage();
  final EncryptionService _encryption = EncryptionService();

  Future<List<Conversation>> getMyConversations() async {
    if (AppConfig.useMockData) return DummyData.conversations;

    final Response res = await _apiClient.get(ApiEndpoints.conversations);
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Conversation> createOrGetConversation({
    String? lawyerId,
    String? clientId,
  }) async {
    if (AppConfig.useMockData) {
      return DummyData.conversations.first;
    }

    final data = <String, dynamic>{
      if (lawyerId != null && lawyerId.isNotEmpty) 'lawyerId': lawyerId,
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
    };

    final Response res =
        await _apiClient.post(ApiEndpoints.conversations, data: data);

    final map = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (map['item'] is Map<String, dynamic>)
        ? map['item'] as Map<String, dynamic>
        : map;

    return Conversation.fromJson(item);
  }

  Future<Map<String, String>> _ensureIdentityKeyPair() async {
    final existing = await _secureStorage.readChatIdentity();
    if (existing != null) {
      await _apiClient.put(
        ApiEndpoints.conversationPublicKey,
        data: {'publicKey': existing['publicKey']},
      );
      return existing;
    }

    final identity = await _encryption.generateIdentityKeyPair();

    await _secureStorage.writeChatIdentity(
      publicKey: identity['publicKey']!,
      privateKey: identity['privateKey']!,
    );

    await _apiClient.put(
      ApiEndpoints.conversationPublicKey,
      data: {'publicKey': identity['publicKey']},
    );

    return identity;
  }

  Future<String> _createAndUploadConversationKey({
    required String conversationId,
    required Map<String, String> identity,
    required String clientPublicKey,
    required String lawyerPublicKey,
  }) async {
    if (clientPublicKey.isEmpty || lawyerPublicKey.isEmpty) {
      throw Exception(
        'Both users must open the updated app once before encrypted chat can start.',
      );
    }

    final conversationKeyBase64 =
        await _encryption.generateConversationKeyBase64();

    final clientWrappedKey = await _encryption.wrapConversationKey(
      conversationKeyBase64: conversationKeyBase64,
      recipientPublicKeyBase64: clientPublicKey,
      senderPrivateKeyBase64: identity['privateKey']!,
      senderPublicKeyBase64: identity['publicKey']!,
    );

    final lawyerWrappedKey = await _encryption.wrapConversationKey(
      conversationKeyBase64: conversationKeyBase64,
      recipientPublicKeyBase64: lawyerPublicKey,
      senderPrivateKeyBase64: identity['privateKey']!,
      senderPublicKeyBase64: identity['publicKey']!,
    );

    await _apiClient.post(
      ApiEndpoints.conversationE2eeKey(conversationId),
      data: {
        'clientWrappedKey': clientWrappedKey,
        'lawyerWrappedKey': lawyerWrappedKey,
      },
    );

    await _secureStorage.writeConversationKey(
      conversationId,
      conversationKeyBase64,
    );

    return conversationKeyBase64;
  }

  Future<String> _ensureConversationKey(String conversationId) async {
    final existing = await _secureStorage.readConversationKey(conversationId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final identity = await _ensureIdentityKeyPair();

    final Response res =
        await _apiClient.get(ApiEndpoints.conversationE2eeKey(conversationId));

    final data = (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : <String, dynamic>{};

    final exists = data['exists'] == true;
    final clientPublicKey = data['clientPublicKey']?.toString() ?? '';
    final lawyerPublicKey = data['lawyerPublicKey']?.toString() ?? '';

    if (!exists) {
      return _createAndUploadConversationKey(
        conversationId: conversationId,
        identity: identity,
        clientPublicKey: clientPublicKey,
        lawyerPublicKey: lawyerPublicKey,
      );
    }

    final wrappedKey = data['wrappedKey'];
    if (wrappedKey is! Map<String, dynamic>) {
      return _createAndUploadConversationKey(
        conversationId: conversationId,
        identity: identity,
        clientPublicKey: clientPublicKey,
        lawyerPublicKey: lawyerPublicKey,
      );
    }

    try {
      final keyBase64 = await _encryption.unwrapConversationKey(
        envelope: wrappedKey,
        recipientPrivateKeyBase64: identity['privateKey']!,
        recipientPublicKeyBase64: identity['publicKey']!,
      );

      await _secureStorage.writeConversationKey(conversationId, keyBase64);
      return keyBase64;
    } catch (_) {
      return _createAndUploadConversationKey(
        conversationId: conversationId,
        identity: identity,
        clientPublicKey: clientPublicKey,
        lawyerPublicKey: lawyerPublicKey,
      );
    }
  }

  List<Map<String, dynamic>> _extractMessageMaps(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    if (data is Map<String, dynamic> && data['items'] is List) {
      return (data['items'] as List).whereType<Map<String, dynamic>>().toList();
    }

    return const [];
  }

  DateTime _parseDate(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();

  String _readString(Map<String, dynamic> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  Future<MessageItem> _mapMessage(
    Map<String, dynamic> raw, {
    required String conversationId,
    String? conversationKeyBase64,
  }) async {
    final messageEncoding =
        raw['messageEncoding']?.toString() ?? raw['encoding']?.toString() ?? '';

    final id = _readString(raw, ['id', 'message_id']);
    final senderId = _readString(
        raw, ['senderId', 'sender_id', 'senderUserId', 'sender_user_id']);
    final nonce = raw['nonce']?.toString();
    final sentAt = _parseDate(
      raw['createdAt'] ?? raw['created_at'] ?? raw['sentAt'] ?? raw['sent_at'],
    );

    if (messageEncoding == 'e2ee-v1') {
      final ciphertext = _readString(raw, ['ciphertext', 'content', 'text']);
      String clearText = '[Encrypted message]';

      if (conversationKeyBase64 != null &&
          conversationKeyBase64.isNotEmpty &&
          ciphertext.isNotEmpty &&
          nonce != null &&
          nonce.isNotEmpty) {
        try {
          clearText = await _encryption.decryptText(
            ciphertextBase64: ciphertext,
            nonceBase64: nonce,
            keyBase64: conversationKeyBase64,
          );
        } catch (_) {
          clearText = '[Unable to decrypt this message]';
        }
      }

      return MessageItem(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: clearText,
        nonce: nonce,
        sentAt: sentAt,
      );
    }

    return MessageItem.fromJson({
      ...raw,
      'conversationId': conversationId,
    });
  }

  Future<List<MessageItem>> getMessages(String conversationId) async {
    if (AppConfig.useMockData) return DummyData.messages[conversationId] ?? [];

    final Response res =
        await _apiClient.get(ApiEndpoints.messages(conversationId));
    final rawItems = _extractMessageMaps(res.data);

    final hasE2ee = rawItems.any(
      (item) => item['messageEncoding']?.toString() == 'e2ee-v1',
    );

    String? conversationKeyBase64;
    if (hasE2ee) {
      conversationKeyBase64 = await _ensureConversationKey(conversationId);
    }

    return Future.wait(
      rawItems.map(
        (raw) => _mapMessage(
          raw,
          conversationId: conversationId,
          conversationKeyBase64: conversationKeyBase64,
        ),
      ),
    );
  }

  Future<MessageItem> sendMessage({
    required String conversationId,
    required String textOrCiphertext,
    String? nonce,
  }) async {
    if (AppConfig.useMockData) {
      final newMsg = MessageItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        senderId: 'u_client',
        content: textOrCiphertext,
        nonce: nonce,
        sentAt: DateTime.now(),
      );
      DummyData.messages.putIfAbsent(conversationId, () => []);
      DummyData.messages[conversationId]!.add(newMsg);
      return newMsg;
    }

    final conversationKeyBase64 = await _ensureConversationKey(conversationId);

    final encrypted = await _encryption.encryptText(
      plaintext: textOrCiphertext,
      keyBase64: conversationKeyBase64,
    );

    final Response res = await _apiClient.post(
      ApiEndpoints.messages(conversationId),
      data: {
        'text': encrypted['ciphertext'],
        'nonce': encrypted['nonce'],
        'messageEncoding': 'e2ee-v1',
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final item = (data['item'] is Map<String, dynamic>)
        ? data['item'] as Map<String, dynamic>
        : data;

    return _mapMessage(
      item,
      conversationId: conversationId,
      conversationKeyBase64: conversationKeyBase64,
    );
  }
}
