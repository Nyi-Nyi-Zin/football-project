class AppConstants {
  AppConstants._();

  // API endpoints are injected for production builds with --dart-define.
  // Localhost remains the safe default for local development.
  static const String apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');
  static const String wsBaseUrlOverride = String.fromEnvironment('WS_BASE_URL');

  static const String baseUrl =
      apiBaseUrlOverride != '' ? apiBaseUrlOverride : 'http://localhost:8080';
  static const String apiVersion = '/api/v1';
  static const String apiBaseUrl = '$baseUrl$apiVersion';

  static const String wsBaseUrl =
      wsBaseUrlOverride != '' ? wsBaseUrlOverride : 'ws://localhost:8080';
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
  // Render free-tier instances may need extra time to wake before auth responds.
  static const Duration authRequestTimeout = Duration(seconds: 45);
}
