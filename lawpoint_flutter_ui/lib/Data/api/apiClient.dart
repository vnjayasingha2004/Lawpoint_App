import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/secureStorage.dart';
import 'apiEndpoints.dart';

class ApiClient {
  ApiClient(String baseUrl, this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 60),
            responseType: ResponseType.json,
          ),
        ),
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
          ),
        ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readAccessToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['Accept'] = 'application/json';

          if (options.data is FormData) {
            options.headers.remove('Content-Type');
            options.contentType = 'multipart/form-data';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final requestOptions = error.requestOptions;

          final shouldTryRefresh = statusCode == 401 &&
              !_isAuthEndpoint(requestOptions.path) &&
              requestOptions.extra['__retried__'] != true;

          if (!shouldTryRefresh) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshAccessToken();

          if (!refreshed) {
            handler.next(error);
            return;
          }

          try {
            final retryResponse = await _retryRequest(requestOptions);
            handler.resolve(retryResponse);
          } on DioException catch (e) {
            handler.next(e);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  final SecureStorage _storage;

  Completer<bool>? _refreshCompleter;

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout') ||
        path.contains('/auth/verify');
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _storage.readRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        await _storage.clearSession();
        _refreshCompleter!.complete(false);
        return false;
      }

      final res = await _refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      final data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};

      final newAccessToken =
          data['accessToken']?.toString() ?? data['token']?.toString() ?? '';
      final newRefreshToken =
          data['refreshToken']?.toString() ?? data['refresh_token']?.toString();

      if (newAccessToken.isEmpty) {
        await _storage.clearSession();
        _refreshCompleter!.complete(false);
        return false;
      }

      await _storage.writeAccessToken(newAccessToken);

      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await _storage.writeRefreshToken(newRefreshToken);
      }

      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      await _storage.clearSession();
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> _retryRequest(RequestOptions requestOptions) async {
    final freshToken = await _storage.readAccessToken();

    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers.remove('content-length');

    if (freshToken != null && freshToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $freshToken';
    } else {
      headers.remove('Authorization');
    }

    final options = Options(
      method: requestOptions.method,
      headers: headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.data is FormData
          ? 'multipart/form-data'
          : requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      validateStatus: requestOptions.validateStatus,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
      extra: {
        ...requestOptions.extra,
        '__retried__': true,
      },
    );

    return _dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
      cancelToken: requestOptions.cancelToken,
      onReceiveProgress: requestOptions.onReceiveProgress,
      onSendProgress: requestOptions.onSendProgress,
    );
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> getBytes(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete(path, data: data, queryParameters: queryParameters);
  }
}
