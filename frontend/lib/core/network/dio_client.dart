import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

class DioClient {
  late final Dio _dio;
  late final Dio _refreshDio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<bool>? _refreshingFuture;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor(),
      _errorInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint('[DIO] $obj'),
      ),
    ]);
  }

  Dio get dio => _dio;

  /// Auth interceptor — attaches JWT token to requests
  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final path = options.path;
        final isAuthRoute = path.contains('/auth/login') ||
            path.contains('/auth/register') ||
            path.contains('/auth/refresh');
        if (isAuthRoute) {
          handler.next(options);
          return;
        }
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final statusCode = error.response?.statusCode;
        final reqPath = error.requestOptions.path;
        final isAuthRoute = reqPath.contains('/auth/login') ||
            reqPath.contains('/auth/register') ||
            reqPath.contains('/auth/refresh');
        final isRefreshCall = reqPath.contains('/auth/refresh');
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (statusCode == 401 &&
            !isAuthRoute &&
            !isRefreshCall &&
            !alreadyRetried) {
          // Try to refresh token
          final refreshed = await _refreshTokenGuarded();
          if (refreshed) {
            // Retry the original request
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            error.requestOptions.extra['retried'] = true;
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    );
  }

  /// Error interceptor — converts Dio errors to app exceptions
  InterceptorsWrapper _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: const ServerException(
                message: 'Connection timed out',
                code: 'TIMEOUT',
              ),
            ),
          );
          return;
        }

        if (error.type == DioExceptionType.connectionError) {
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: const ServerException(
                message: 'No internet connection',
                code: 'NETWORK_ERROR',
              ),
            ),
          );
          return;
        }

        handler.next(error);
      },
    );
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshToken() async {
    try {
      final refreshToken =
          await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) {
        await clearTokens();
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final tokens = response.data['data']['tokens'];
        await _storage.write(
          key: AppConstants.accessTokenKey,
          value: tokens['access_token'],
        );
        await _storage.write(
          key: AppConstants.refreshTokenKey,
          value: tokens['refresh_token'],
        );
        return true;
      }
      await clearTokens();
      return false;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Future<bool> _refreshTokenGuarded() async {
    final inFlight = _refreshingFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshToken();
    _refreshingFuture = future;
    try {
      return await future;
    } finally {
      _refreshingFuture = null;
    }
  }

  /// Save tokens after login/register
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  /// Clear tokens on logout
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  /// Ensure an access token exists and is still valid.
  Future<bool> ensureValidAccessToken() async {
    final accessToken = await _storage.read(key: AppConstants.accessTokenKey);
    if (accessToken != null && !_isJwtExpired(accessToken)) {
      return true;
    }

    return _refreshTokenGuarded();
  }

  /// Check if user has stored tokens
  Future<bool> hasTokens() async {
    final accessToken = await _storage.read(key: AppConstants.accessTokenKey);
    final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
    return accessToken != null || refreshToken != null;
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }

      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final claims = jsonDecode(payload) as Map<String, dynamic>;
      final exp = claims['exp'];
      if (exp is! num) {
        return true;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );

      // Refresh slightly early to avoid requests racing the expiry boundary.
      return !expiry.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true;
    }
  }
}
