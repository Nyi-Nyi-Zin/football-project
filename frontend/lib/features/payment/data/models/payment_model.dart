import '../../domain/entities/payment_entity.dart';

class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final double reservedBalance;
  final String currency;
  final String status;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.reservedBalance,
    required this.currency,
    required this.status,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      reservedBalance: (json['reserved_balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'MMK',
      status: json['status'] as String? ?? 'active',
    );
  }

  Wallet toEntity() {
    return Wallet(
      id: id,
      userId: userId,
      balance: balance,
      reservedBalance: reservedBalance,
      currency: currency,
      status: status,
    );
  }
}

class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MMK',
      status: json['status'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Transaction toEntity() {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      currency: currency,
      status: status,
      description: description,
      createdAt: createdAt,
    );
  }
}

class WithdrawalSubmissionModel {
  final TransactionModel transaction;
  final String verificationCode;
  final String assignedAgentId;
  final String requestStatus;

  const WithdrawalSubmissionModel({
    required this.transaction,
    required this.verificationCode,
    required this.assignedAgentId,
    required this.requestStatus,
  });

  factory WithdrawalSubmissionModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalSubmissionModel(
      transaction: TransactionModel.fromJson(json),
      verificationCode: json['verification_code'] as String? ?? '',
      assignedAgentId: json['assigned_agent_id'] as String? ?? '',
      requestStatus: json['request_status'] as String? ?? 'pending',
    );
  }

  WithdrawalSubmission toEntity() {
    return WithdrawalSubmission(
      transaction: transaction.toEntity(),
      verificationCode: verificationCode,
      assignedAgentId: assignedAgentId,
      requestStatus: requestStatus,
    );
  }
}
