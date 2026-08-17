import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

// --- Dependency providers ---

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.read(dioClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.read(authRemoteDataSourceProvider),
    ref.read(dioClientProvider),
  );
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.read(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.read(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.read(authRepositoryProvider));
});

// --- Auth state notifier ---

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  // Keep the mobile UI responsive when the hosted backend is cold, down, or unreachable.
  // Users can retry after the clear timeout message instead of seeing an indefinite spinner.
  static const _authRequestTimeout = Duration(seconds: 15);

  final Ref _ref;
  Future<void>? _restoreFuture;
  int _authOperation = 0;

  AuthNotifier(this._ref) : super(const AsyncLoading()) {
    restoreSession(isInitialLoad: true);
  }

  Future<void> restoreSession({bool isInitialLoad = false}) async {
    final inFlight = _restoreFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _restoreSessionInternal(isInitialLoad: isInitialLoad);
    _restoreFuture = future;
    try {
      await future;
    } finally {
      _restoreFuture = null;
    }
  }

  Future<void> _restoreSessionInternal({required bool isInitialLoad}) async {
    final operation = _authOperation;
    final repo = _ref.read(authRepositoryProvider);
    final dioClient = _ref.read(dioClientProvider);
    final currentUser = state.valueOrNull;

    if (isInitialLoad) {
      state = const AsyncLoading();
    }

    final hasSession = await dioClient.hasTokens();
    if (!_isCurrentOperation(operation)) return;
    if (!hasSession) {
      state = const AsyncData(null);
      return;
    }

    final accessTokenReady = await dioClient.ensureValidAccessToken();
    if (!_isCurrentOperation(operation)) return;
    if (!accessTokenReady) {
      state = const AsyncData(null);
      return;
    }

    final profileResult = await repo.getProfile();
    if (!_isCurrentOperation(operation)) return;
    Failure? failure;
    final nextState = profileResult.fold<AsyncValue<User?>>(
      (err) {
        failure = err;
        if (_shouldClearSession(err)) {
          return const AsyncData(null);
        }
        if (currentUser != null) {
          return AsyncData(currentUser);
        }
        return AsyncError(err, StackTrace.current);
      },
      AsyncData.new,
    );

    if (failure != null && _shouldClearSession(failure!)) {
      await dioClient.clearTokens();
    }

    if (_isCurrentOperation(operation)) {
      state = nextState;
    }
  }

  Future<User?> login(
    String email,
    String password, {
    bool deferNavigation = false,
  }) async {
    final operation = ++_authOperation;
    state = const AsyncLoading();
    try {
      final result = await _ref
          .read(loginUseCaseProvider)
          .call(LoginParams(email: email, password: password))
          .timeout(_authRequestTimeout);

      if (!_isCurrentOperation(operation)) return null;
      final user = result.fold<User?>(
        (failure) {
          state = AsyncError(failure, StackTrace.current);
          return null;
        },
        (authResult) {
          state = deferNavigation
              ? const AsyncData(null)
              : AsyncData(authResult.user);
          return authResult.user;
        },
      );
      return user;
    } on TimeoutException {
      if (_isCurrentOperation(operation)) {
        state = AsyncError(
          const ServerFailure(
            message:
                'Connection timed out. Please check your internet connection and try again.',
            code: 'TIMEOUT',
          ),
          StackTrace.current,
        );
      }
      return null;
    } catch (error, stackTrace) {
      if (_isCurrentOperation(operation)) {
        state = AsyncError(
          ServerFailure(message: 'Unable to connect to the server: $error'),
          stackTrace,
        );
      }
      return null;
    }
  }

  Future<User?> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final operation = ++_authOperation;
    state = const AsyncLoading();
    try {
      final result = await _ref
          .read(registerUseCaseProvider)
          .call(
            RegisterParams(
              email: email,
              username: username,
              password: password,
              fullName: fullName,
              phone: phone,
            ),
          )
          .timeout(_authRequestTimeout);

      if (!_isCurrentOperation(operation)) return null;
      final user = result.fold<User?>(
        (failure) {
          state = AsyncError(failure, StackTrace.current);
          return null;
        },
        (authResult) {
          // Registration creates an account but does not authenticate automatically.
          state = const AsyncData(null);
          return authResult.user;
        },
      );
      return user;
    } on TimeoutException {
      if (_isCurrentOperation(operation)) {
        state = AsyncError(
          const ServerFailure(
            message:
                'Connection timed out. Your account was not confirmed. Please try again.',
            code: 'TIMEOUT',
          ),
          StackTrace.current,
        );
      }
      return null;
    } catch (error, stackTrace) {
      if (_isCurrentOperation(operation)) {
        state = AsyncError(
          ServerFailure(message: 'Unable to connect to the server: $error'),
          stackTrace,
        );
      }
      return null;
    }
  }

  void setAuthenticated(User user) {
    _authOperation++;
    state = AsyncData(user);
  }

  bool _isCurrentOperation(int operation) => operation == _authOperation;

  Future<void> logout() async {
    _authOperation++;
    await _ref.read(logoutUseCaseProvider).call();
    state = const AsyncData(null);
  }

  Future<Either<Failure, User>> updateProfile({
    String? fullName,
    String? phone,
    String? nrc,
    String? nrcRegion,
    String? nrcTownship,
    String? nrcType,
    String? nrcNumber,
    int? nrcRegionId,
    int? nrcTownshipId,
    int? nrcTypeId,
    String? gmail,
    String? location,
    String? customCode,
  }) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) {
      return const Left(AuthFailure(message: 'Not authenticated'));
    }

    final result = await _ref.read(authRepositoryProvider).updateProfile(
          fullName: fullName,
          phone: phone,
          nrc: nrc,
          nrcRegion: nrcRegion,
          nrcTownship: nrcTownship,
          nrcType: nrcType,
          nrcNumber: nrcNumber,
          nrcRegionId: nrcRegionId,
          nrcTownshipId: nrcTownshipId,
          nrcTypeId: nrcTypeId,
          gmail: gmail,
          location: location,
          customCode: customCode,
        );

    result.fold(
      (_) {},
      (user) => state = AsyncData(user),
    );

    return result;
  }

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }

  bool _shouldClearSession(Failure failure) {
    if (failure is AuthFailure) {
      return true;
    }

    final code = failure.code?.toUpperCase();
    if (code == 'AUTH_ERROR' || code == 'UNAUTHORIZED') {
      return true;
    }

    final message = failure.message.toLowerCase();
    return message.contains('unauthorized') ||
        message.contains('invalid or expired token') ||
        message.contains('invalid or expired refresh token');
  }

  Future<Either<Failure, List<dynamic>>> getNRCCodes() async {
    return _ref.read(authRepositoryProvider).getNRCCodes();
  }

  Future<Either<Failure, List<dynamic>>> getNRCTownships(int codeId) async {
    return _ref.read(authRepositoryProvider).getNRCTownships(codeId);
  }
}
