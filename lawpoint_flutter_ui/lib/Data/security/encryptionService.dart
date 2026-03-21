import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class EncryptionService {
  final Cipher _aes = AesGcm.with256bits();
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<Map<String, String>> generateIdentityKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();

    return {
      'privateKey': base64Encode(privateKeyBytes),
      'publicKey': base64Encode(publicKey.bytes),
    };
  }

  Future<String> generateConversationKeyBase64() async {
    final rng = Random.secure();
    final keyBytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64Encode(keyBytes);
  }

  Future<Map<String, String>> encryptText({
    required String plaintext,
    required String keyBase64,
  }) async {
    final nonce = _aes.newNonce();
    final secretBox = await _aes.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(base64Decode(keyBase64)),
      nonce: nonce,
    );

    return {
      'ciphertext': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
      'nonce': base64Encode(secretBox.nonce),
    };
  }

  Future<String> decryptText({
    required String ciphertextBase64,
    required String nonceBase64,
    required String keyBase64,
  }) async {
    final combined = base64Decode(ciphertextBase64);
    final cipherText = combined.sublist(0, combined.length - 16);
    final macBytes = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: base64Decode(nonceBase64),
      mac: Mac(macBytes),
    );

    final clearBytes = await _aes.decrypt(
      secretBox,
      secretKey: SecretKey(base64Decode(keyBase64)),
    );

    return utf8.decode(clearBytes);
  }

  Future<Map<String, String>> wrapConversationKey({
    required String conversationKeyBase64,
    required String recipientPublicKeyBase64,
    required String senderPrivateKeyBase64,
    required String senderPublicKeyBase64,
  }) async {
    final wrappingKey = await _deriveWrappingKey(
      localPrivateKeyBase64: senderPrivateKeyBase64,
      localPublicKeyBase64: senderPublicKeyBase64,
      remotePublicKeyBase64: recipientPublicKeyBase64,
    );

    final nonce = _aes.newNonce();
    final secretBox = await _aes.encrypt(
      base64Decode(conversationKeyBase64),
      secretKey: wrappingKey,
      nonce: nonce,
    );

    return {
      'senderPublicKey': senderPublicKeyBase64,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode(secretBox.cipherText + secretBox.mac.bytes),
    };
  }

  Future<String> unwrapConversationKey({
    required Map<String, dynamic> envelope,
    required String recipientPrivateKeyBase64,
    required String recipientPublicKeyBase64,
  }) async {
    final senderPublicKeyBase64 = envelope['senderPublicKey']?.toString() ?? '';
    final nonceBase64 = envelope['nonce']?.toString() ?? '';
    final ciphertextBase64 = envelope['ciphertext']?.toString() ?? '';

    if (senderPublicKeyBase64.isEmpty ||
        nonceBase64.isEmpty ||
        ciphertextBase64.isEmpty) {
      throw Exception('Invalid wrapped conversation key envelope.');
    }

    final wrappingKey = await _deriveWrappingKey(
      localPrivateKeyBase64: recipientPrivateKeyBase64,
      localPublicKeyBase64: recipientPublicKeyBase64,
      remotePublicKeyBase64: senderPublicKeyBase64,
    );

    final combined = base64Decode(ciphertextBase64);
    final cipherText = combined.sublist(0, combined.length - 16);
    final macBytes = combined.sublist(combined.length - 16);

    final secretBox = SecretBox(
      cipherText,
      nonce: base64Decode(nonceBase64),
      mac: Mac(macBytes),
    );

    final clearBytes = await _aes.decrypt(
      secretBox,
      secretKey: wrappingKey,
    );

    return base64Encode(clearBytes);
  }

  Future<SecretKey> _deriveWrappingKey({
    required String localPrivateKeyBase64,
    required String localPublicKeyBase64,
    required String remotePublicKeyBase64,
  }) async {
    final localKeyPair = SimpleKeyPairData(
      base64Decode(localPrivateKeyBase64),
      publicKey: SimplePublicKey(
        base64Decode(localPublicKeyBase64),
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );

    final remotePublicKey = SimplePublicKey(
      base64Decode(remotePublicKeyBase64),
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: localKeyPair,
      remotePublicKey: remotePublicKey,
    );

    return _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: const [],
      info: utf8.encode('lawpoint-chat-e2ee-v1'),
    );
  }
}
