import 'package:equatable/equatable.dart';

/// Pure Dart user entity — no framework dependency
class User extends Equatable {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String phone;
  final String role;
  final String status;
  final double balance;
  final DateTime createdAt;
  final String? nrc;
  final String? nrcRegion;
  final String? nrcTownship;
  final String? nrcType;
  final String? nrcNumber;
  final int? nrcRegionId;
  final int? nrcTownshipId;
  final int? nrcTypeId;
  final String? gmail;
  final String? location;
  final String? customCode;

  const User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.status,
    required this.balance,
    required this.createdAt,
    this.nrc,
    this.nrcRegion,
    this.nrcTownship,
    this.nrcType,
    this.nrcNumber,
    this.nrcRegionId,
    this.nrcTownshipId,
    this.nrcTypeId,
    this.gmail,
    this.location,
    this.customCode,
  });

  @override
  List<Object?> get props => [id, email, username, nrc, nrcRegion, nrcTownship, nrcType, nrcNumber, nrcRegionId, nrcTownshipId, nrcTypeId, gmail, location, customCode];
}

/// Token pair entity
class TokenPair extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken, expiresAt];
}

/// Auth result containing user + tokens
class AuthResult extends Equatable {
  final User user;
  final TokenPair tokens;

  const AuthResult({required this.user, required this.tokens});

  @override
  List<Object?> get props => [user, tokens];
}
