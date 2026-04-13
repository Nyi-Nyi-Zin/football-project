class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'http://localhost:8080';
  static const String apiVersion = '/api/v1';
  static const String apiBaseUrl = '$baseUrl$apiVersion';
  static const String wsBaseUrl = 'ws://localhost:8080';
  static const String wsOddsUrl = '$wsBaseUrl/ws/odds';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
