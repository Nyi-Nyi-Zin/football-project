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
  final Ref _ref;
  Future<void>? _restoreFuture;

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
    final repo = _ref.read(authRepositoryProvider);
    final dioClient = _ref.read(dioClientProvider);
    final currentUser = state.valueOrNull;

    if (isInitialLoad) {
      state = const AsyncLoading();
    }

    final hasSession = await dioClient.hasTokens();
    if (!hasSession) {
      state = const AsyncData(null);
      return;
    }

    final accessTokenReady = await dioClient.ensureValidAccessToken();
    if (!accessTokenReady) {
      state = const AsyncData(null);
      return;
    }

    final profileResult = await repo.getProfile();
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

    state = nextState;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final result = await _ref
        .read(loginUseCaseProvider)
        .call(LoginParams(email: email, password: password));

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (authResult) => AsyncData(authResult.user),
    );
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    state = const AsyncLoading();
    final result = await _ref.read(registerUseCaseProvider).call(
          RegisterParams(
            email: email,
            username: username,
            password: password,
            fullName: fullName,
            phone: phone,
          ),
        );

    state = result.fold(
      (failure) => AsyncError(failure, StackTrace.current),
      (authResult) => AsyncData(authResult.user),
    );
  }

  Future<void> logout() async {
    await _ref.read(logoutUseCaseProvider).call();
    state = const AsyncData(null);
  }

  Future<Either<Failure, User>> updateProfile({
    String? fullName,
    String? phone,
  }) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) {
      return const Left(AuthFailure(message: 'Not authenticated'));
    }

    final result = await _ref.read(authRepositoryProvider).updateProfile(
          fullName: fullName,
          phone: phone,
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
}
