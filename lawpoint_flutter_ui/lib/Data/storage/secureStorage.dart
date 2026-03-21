import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kChatPublicKey = 'chat_public_key';
  static const _kChatPrivateKey = 'chat_private_key';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);

  Future<void> deleteAccessToken() => _storage.delete(key: _kAccessToken);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> deleteRefreshToken() => _storage.delete(key: _kRefreshToken);

  Future<void> clearSession() async {
    await deleteAccessToken();
    await deleteRefreshToken();
  }

  Future<void> writeChatIdentity({
    required String publicKey,
    required String privateKey,
  }) async {
    await _storage.write(key: _kChatPublicKey, value: publicKey);
    await _storage.write(key: _kChatPrivateKey, value: privateKey);
  }

  Future<Map<String, String>?> readChatIdentity() async {
    final publicKey = await _storage.read(key: _kChatPublicKey);
    final privateKey = await _storage.read(key: _kChatPrivateKey);

    if (publicKey == null ||
        publicKey.isEmpty ||
        privateKey == null ||
        privateKey.isEmpty) {
      return null;
    }

    return {
      'publicKey': publicKey,
      'privateKey': privateKey,
    };
  }

  Future<void> deleteChatIdentity() async {
    await _storage.delete(key: _kChatPublicKey);
    await _storage.delete(key: _kChatPrivateKey);
  }

  String _conversationKeyName(String conversationId) =>
      'conversation_key_$conversationId';

  Future<void> writeConversationKey(
    String conversationId,
    String keyBase64,
  ) =>
      _storage.write(
        key: _conversationKeyName(conversationId),
        value: keyBase64,
      );

  Future<String?> readConversationKey(String conversationId) =>
      _storage.read(key: _conversationKeyName(conversationId));

  Future<void> deleteConversationKey(String conversationId) =>
      _storage.delete(key: _conversationKeyName(conversationId));

  Future<void> clearAll() => _storage.deleteAll();
}
