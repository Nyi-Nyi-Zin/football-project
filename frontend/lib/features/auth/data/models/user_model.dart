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
  final bool isEmailVerified;
  final bool isPhoneVerified;
  final String kycStatus;
  final int pendingWithdrawalCount;
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
  final String? region;
  final String? township;
  final String? customCode;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.status,
    required this.balance,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.kycStatus = 'pending',
    this.pendingWithdrawalCount = 0,
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
    this.region,
    this.township,
    this.customCode,
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
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      pendingWithdrawalCount: json['pending_withdrawal_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      nrc: json['nrc'] as String?,
      nrcRegion: json['nrc_region'] as String?,
      nrcTownship: json['nrc_township'] as String?,
      nrcType: json['nrc_type'] as String?,
      nrcNumber: json['nrc_number'] as String?,
      nrcRegionId: json['nrc_region_id'] as int?,
      nrcTownshipId: json['nrc_township_id'] as int?,
      nrcTypeId: json['nrc_type_id'] as int?,
      gmail: json['gmail'] as String?,
      location: json['location'] as String?,
      region: json['region'] as String?,
      township: json['township'] as String?,
      customCode: json['custom_code'] as String?,
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
      'is_email_verified': isEmailVerified,
      'is_phone_verified': isPhoneVerified,
      'kyc_status': kycStatus,
      'pending_withdrawal_count': pendingWithdrawalCount,
      'created_at': createdAt.toIso8601String(),
      'nrc': nrc,
      'nrc_region': nrcRegion,
      'nrc_township': nrcTownship,
      'nrc_type': nrcType,
      'nrc_number': nrcNumber,
      'nrc_region_id': nrcRegionId,
      'nrc_township_id': nrcTownshipId,
      'nrc_type_id': nrcTypeId,
      'gmail': gmail,
      'location': location,
      'region': region,
      'township': township,
      'custom_code': customCode,
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
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
      kycStatus: kycStatus,
      pendingWithdrawalCount: pendingWithdrawalCount,
      createdAt: createdAt,
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
