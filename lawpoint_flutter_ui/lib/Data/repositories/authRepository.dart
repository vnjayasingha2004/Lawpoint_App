import 'package:dio/dio.dart';

import '../../Models/auth_result.dart';
import '../../Models/user.dart';
import '../api/apiClient.dart';
import '../api/apiEndpoints.dart';
import '../storage/appConfig.dart';
import '../lawyer_form_options.dart';
import '../storage/secureStorage.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._secureStorage);

  final ApiClient _apiClient;
  final SecureStorage _secureStorage;

  Future<void> clearLocalSession() async {
    await _secureStorage.clearSession();
  }

  Future<User> login({
    required String identifier,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      final role = identifier.toLowerCase().contains('law')
          ? UserRole.lawyer
          : UserRole.client;
      final user = User(
        id: role == UserRole.lawyer ? 'u_lawyer' : 'u_client',
        email: identifier.contains('@') ? identifier : '',
        phone: identifier.contains('@') ? '' : identifier,
        fullName: role == UserRole.lawyer ? 'Mock Lawyer' : 'Mock Client',
        role: role,
        verified: role == UserRole.lawyer ? true : null,
      );
      await _secureStorage.writeAccessToken('mock_token');
      return user;
    }

    final isEmail = identifier.contains('@');
    final Response res = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        if (isEmail) 'email': identifier else 'phone': identifier,
        'password': password,
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    final token =
        data['accessToken']?.toString() ?? data['token']?.toString() ?? '';
    final refreshToken =
        data['refreshToken']?.toString() ?? data['refresh_token']?.toString();

    if (token.isEmpty) {
      throw Exception('Login did not return an access token.');
    }

    await _secureStorage.writeAccessToken(token);

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.writeRefreshToken(refreshToken);
    } else {
      await _secureStorage.deleteRefreshToken();
    }

    final dynamic userJson = data['user'] ?? data['item'];
    if (userJson is Map<String, dynamic>) {
      return User.fromJson(userJson);
    }

    return getMe();
  }

  Future<User> getMe() async {
    if (AppConfig.useMockData) {
      final token = await _secureStorage.readAccessToken();
      if (token == null || token.isEmpty) throw Exception('No token');
      return const User(
        id: 'u_client',
        email: 'client@example.com',
        phone: '',
        fullName: 'Mock Client',
        role: UserRole.client,
      );
    }

    final res = await _apiClient.get(ApiEndpoints.me);
    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final userJson = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : (data['item'] is Map<String, dynamic>)
            ? data['item'] as Map<String, dynamic>
            : data;
    return User.fromJson(userJson);
  }

  Future<void> logout() async {
    try {
      if (!AppConfig.useMockData) {
        final refreshToken = await _secureStorage.readRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _apiClient.post(
            ApiEndpoints.logout,
            data: {'refreshToken': refreshToken},
          );
        }
      }
    } catch (_) {
    } finally {
      await _secureStorage.clearSession();
    }
  }

  Future<AuthRegistrationResult> registerClient({
    required String fullName,
    required String email,
    required String password,
  }) async {
    if (AppConfig.useMockData) {
      return const AuthRegistrationResult(otpRequired: false);
    }

    final Response res = await _apiClient.post(
      ApiEndpoints.registerClient,
      data: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    return AuthRegistrationResult.fromJson(data);
  }

  Future<AuthRegistrationResult> registerLawyer({
    required String fullName,
    required String email,
    required String password,
    required String enrolmentNo,
    required String baslId,
    required List<String> districts,
    required List<String> languages,
  }) async {
    if (AppConfig.useMockData) {
      return const AuthRegistrationResult(otpRequired: false);
    }

    final Response res = await _apiClient.post(
      ApiEndpoints.registerLawyer,
      data: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
        'enrolmentNo': enrolmentNo.trim(),
        'baslId': baslId.trim(),
        'district': joinMultiSelectText(districts),
        'languages': normalizeSelectedValues(languages),
      },
    );

    final data = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};

    return AuthRegistrationResult.fromJson(data);
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    if (AppConfig.useMockData) return;

    await _apiClient.post(
      ApiEndpoints.verifyEmail,
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
      },
    );
  }
}
