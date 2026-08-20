import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final DioClient _dioClient;

  AuthRepositoryImpl(this._remoteDataSource, this._dioClient);

  @override
  Future<Either<Failure, AuthResult>> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _remoteDataSource.login(email, password);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final tokens =
          TokenPairModel.fromJson(data['tokens'] as Map<String, dynamic>);

      // Save tokens
      await _dioClient.saveTokens(tokens.accessToken, tokens.refreshToken);

      return Right(AuthResult(
        user: user.toEntity(),
        tokens: tokens.toEntity(),
      ));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthResult>> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final data = await _remoteDataSource.register(
        email: email,
        username: username,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final tokens =
          TokenPairModel.fromJson(data['tokens'] as Map<String, dynamic>);

      // Registration creates the account but does not start a session.
      return Right(AuthResult(
        user: user.toEntity(),
        tokens: tokens.toEntity(),
      ));
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      final model = await _remoteDataSource.getProfile();
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
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
    String? region,
    String? township,
    String? customCode,
  }) async {
    try {
      final model = await _remoteDataSource.updateProfile(
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
        region: region,
        township: township,
        customCode: customCode,
      );
      return Right(model.toEntity());
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyEmail(String code) async {
    try {
      await _remoteDataSource.verifyEmail(code);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyPhone(String code) async {
    try {
      await _remoteDataSource.verifyPhone(code);
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitKYC({
    required String nationalId,
    required String kycImageUrl,
  }) async {
    try {
      await _remoteDataSource.submitKYC(
        nationalId: nationalId,
        kycImageUrl: kycImageUrl,
      );
      return const Right(null);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _dioClient.clearTokens();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    return _dioClient.hasTokens();
  }

  @override
  Future<Either<Failure, List<dynamic>>> getNRCCodes() async {
    try {
      final codes = await _remoteDataSource.getNRCCodes();
      return Right(codes);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<dynamic>>> getNRCTownships(int codeId) async {
    try {
      final townships = await _remoteDataSource.getNRCTownships(codeId);
      return Right(townships);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  Failure _handleDioError(DioException e) {
    if (e.error is ServerException) {
      final exception = e.error as ServerException;
      if (exception.code == 'NETWORK_ERROR') {
        return NetworkFailure(message: exception.message, code: exception.code);
      }
      return ServerFailure(
        message: exception.message,
        code: exception.code,
      );
    }

    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        final error = data['error'] as Map<String, dynamic>;
        return ServerFailure(
          message: error['message'] as String? ?? 'Unknown error',
          code: error['code'] as String?,
        );
      }
      return ServerFailure(
        message: 'Server error: ${e.response!.statusCode}',
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return const ServerFailure(
        message: 'Connection timed out. Please try again.',
        code: 'TIMEOUT',
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return const NetworkFailure();
    }
    return ServerFailure(message: e.message ?? 'Unknown error');
  }
}
