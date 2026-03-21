import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../Models/auth_result.dart';
import '../../Models/user.dart';
import '../repositories/authRepository.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository);

  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.initializing;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _status == AuthStatus.authenticated && _user != null;

  String _messageFromError(Object error, {required String fallback}) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['error'] ?? data['message'];
        if (msg != null && msg.toString().trim().isNotEmpty) {
          return msg.toString();
        }
      }
    }
    final text = error.toString();
    if (text.trim().isNotEmpty) return text;
    return fallback;
  }

  Future<void> init() async {
    _status = AuthStatus.initializing;
    notifyListeners();

    try {
      final me = await _authRepository.getMe();
      _user = me;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (_) {
      await _authRepository.clearLocalSession();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    }

    notifyListeners();
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final u = await _authRepository.login(
        identifier: identifier,
        password: password,
      );
      _user = u;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      await _authRepository.clearLocalSession();
      _errorMessage = _messageFromError(
        e,
        fallback: 'Login failed. Please check your details.',
      );
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<AuthRegistrationResult?> registerClient({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.registerClient(
        fullName: fullName,
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      _errorMessage =
          _messageFromError(e, fallback: 'Registration failed. Try again.');
      notifyListeners();
      return null;
    }
  }

  Future<AuthRegistrationResult?> registerLawyer({
    required String fullName,
    required String email,
    required String password,
    required String enrolmentNo,
    required String baslId,
    required List<String> districts,
    required List<String> languages,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.registerLawyer(
        fullName: fullName,
        email: email,
        password: password,
        enrolmentNo: enrolmentNo,
        baslId: baslId,
        districts: districts,
        languages: languages,
      );
      return result;
    } catch (e) {
      _errorMessage =
          _messageFromError(e, fallback: 'Registration failed. Try again.');
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String code,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.verifyEmail(email: email, code: code);
      return true;
    } catch (e) {
      _errorMessage =
          _messageFromError(e, fallback: 'Verification failed. Try again.');
      notifyListeners();
      return false;
    }
  }
}
