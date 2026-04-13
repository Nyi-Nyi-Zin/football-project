import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
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

  AuthNotifier(this._ref) : super(const AsyncLoading()) {
    _init();
  }

  Future<void> _init() async {
    final repo = _ref.read(authRepositoryProvider);
    final isAuth = await repo.isAuthenticated();
    if (isAuth) {
      final profileResult = await repo.getProfile();
      state = profileResult.fold(
        (failure) => const AsyncData(null),
        (user) => AsyncData(user),
      );
    } else {
      state = const AsyncData(null);
    }
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
}
