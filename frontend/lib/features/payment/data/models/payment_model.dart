import '../../domain/entities/payment_entity.dart';

class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final String status;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
    required this.status,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MMK',
      status: json['status'] as String? ?? 'active',
    );
  }

  Wallet toEntity() {
    return Wallet(
      id: id,
      userId: userId,
      balance: balance,
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
