import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Abstract auth repository interface — domain layer
abstract class AuthRepository {
  Future<Either<Failure, AuthResult>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AuthResult>> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<Either<Failure, User>> getProfile();

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
  });

  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, void>> logout();

  Future<bool> isAuthenticated();

  Future<Either<Failure, List<dynamic>>> getNRCCodes();

  Future<Either<Failure, List<dynamic>>> getNRCTownships(int codeId);
}
