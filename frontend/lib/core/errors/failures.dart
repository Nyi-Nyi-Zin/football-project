import 'package:equatable/equatable.dart';

/// Base failure class for the app
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => message;
}

/// Server returned an error
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Network connection issue
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code = 'NETWORK_ERROR',
  });
}

/// Local cache/storage error
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error',
    super.code = 'CACHE_ERROR',
  });
}

/// Authentication failure
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.code = 'AUTH_ERROR',
  });
}

/// Validation failure
class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Generic app exception
class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException: [$code] $message';
}

/// Server exception with status code
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    super.code,
    this.statusCode,
  });
}
