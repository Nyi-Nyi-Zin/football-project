import '../../domain/entities/user_entity.dart';

/// User data model — maps to/from JSON
class UserModel {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String phone;
  final String role;
  final String status;
  final double balance;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.status,
    required this.balance,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'active',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'phone': phone,
      'role': role,
      'status': status,
      'balance': balance,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to domain entity
  User toEntity() {
    return User(
      id: id,
      email: email,
      username: username,
      fullName: fullName,
      phone: phone,
      role: role,
      status: status,
      balance: balance,
      createdAt: createdAt,
    );
  }
}

/// Token pair model
class TokenPairModel {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;

  const TokenPairModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory TokenPairModel.fromJson(Map<String, dynamic> json) {
    return TokenPairModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: json['expires_at'] as int,
    );
  }

  TokenPair toEntity() {
    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
}
