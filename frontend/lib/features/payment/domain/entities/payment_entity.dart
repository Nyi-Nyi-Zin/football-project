import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String id;
  final String userId;
  final double balance;
  final String currency;
  final String status;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.currency,
    required this.status,
  });

  @override
  List<Object?> get props => [id, balance];
}

class Transaction extends Equatable {
  final String id;
  final String type; // 'deposit', 'withdrawal', 'bet_placed', 'bet_won'
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.description,
    required this.createdAt,
  });

  bool get isCredit => type == 'deposit' || type == 'bet_won';

  @override
  List<Object?> get props => [id];
}
