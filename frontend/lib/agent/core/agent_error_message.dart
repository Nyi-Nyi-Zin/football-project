import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';

String agentFriendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ServerException) {
    return _messageForStatus(error.statusCode, error.message, fallback);
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Connection unavailable. Tap Resync and try again.';
    }

    final status = error.response?.statusCode;
    final data = error.response?.data;
    String? serverMessage;
    if (data is Map) {
      final nested = data['error'];
      if (nested is Map && nested['message'] is String) {
        serverMessage = nested['message'] as String;
      } else if (data['message'] is String) {
        serverMessage = data['message'] as String;
      }
    }
    return _messageForStatus(status, serverMessage, fallback);
  }

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Failed host lookup')) {
    return 'Connection unavailable. Tap Resync and try again.';
  }
  return fallback;
}

String _messageForStatus(int? status, String? serverMessage, String fallback) {
  switch (status) {
    case 400:
      return serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'The request could not be completed. Check the information and try again.';
    case 401:
      return 'Your session has expired. Please sign in again.';
    case 403:
      return 'You are not allowed to perform this action.';
    case 404:
      return 'The requested record was not found.';
    case 409:
      return serverMessage?.isNotEmpty == true
          ? serverMessage!
          : 'This request is no longer available or was already processed.';
    case 429:
      return 'Too many requests. Please wait a moment and try again.';
    case 500:
    case 502:
    case 503:
      return 'The service is temporarily unavailable. Please try again shortly.';
    default:
      return serverMessage?.isNotEmpty == true ? serverMessage! : fallback;
  }
}
