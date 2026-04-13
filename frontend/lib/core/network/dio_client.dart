import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../errors/failures.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

class DioClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

    _dio.interceptors.addAll([
      _authInterceptor(),
      _errorInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => print('[DIO] $obj'),
      ),
    ]);
  }

  Dio get dio => _dio;

  /// Auth interceptor — attaches JWT token to requests
  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the original request
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
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
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConstants.apiBaseUrl}/auth/refresh',
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
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Save tokens after login/register
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  /// Clear tokens on logout
  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  /// Check if user has stored tokens
  Future<bool> hasTokens() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }
}
