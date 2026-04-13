import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Login use case
class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, AuthResult>> call(LoginParams params) {
    return _repository.login(
      email: params.email,
      password: params.password,
    );
  }
}

class LoginParams {
  final String email;
  final String password;

  const LoginParams({required this.email, required this.password});
}

/// Register use case
class RegisterUseCase {
  final AuthRepository _repository;

  RegisterUseCase(this._repository);

  Future<Either<Failure, AuthResult>> call(RegisterParams params) {
    return _repository.register(
      email: params.email,
      username: params.username,
      password: params.password,
      fullName: params.fullName,
      phone: params.phone,
    );
  }
}

class RegisterParams {
  final String email;
  final String username;
  final String password;
  final String fullName;
  final String? phone;

  const RegisterParams({
    required this.email,
    required this.username,
    required this.password,
    required this.fullName,
    this.phone,
  });
}

/// Get profile use case
class GetProfileUseCase {
  final AuthRepository _repository;

  GetProfileUseCase(this._repository);

  Future<Either<Failure, User>> call() {
    return _repository.getProfile();
  }
}

/// Logout use case
class LogoutUseCase {
  final AuthRepository _repository;

  LogoutUseCase(this._repository);

  Future<Either<Failure, void>> call() {
    return _repository.logout();
  }
}
