import 'package:equatable/equatable.dart';

class Wallet extends Equatable {
  final String id;
  final String userId;
  final double balance;
  final double reservedBalance;
  final String currency;
  final String status;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.reservedBalance,
    required this.currency,
    required this.status,
  });

  double get availableBalance => balance - reservedBalance;

  @override
  List<Object?> get props => [id, balance, reservedBalance];
}

class Transaction extends Equatable {
  final String id;
  final String type; // deposit, withdraw, bet_stake, bet_win, cash_out, refund
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

  bool get isCredit =>
      type == 'deposit' ||
      type == 'bet_win' ||
      type == 'cash_out' ||
      type == 'refund';

  bool get isDebit => !isCredit;

  String get displayType => type.replaceAll('_', ' ').toUpperCase();

  @override
  List<Object?> get props => [id];
}

class WithdrawalSubmission extends Equatable {
  final Transaction transaction;
  final String verificationCode;
  final String assignedAgentId;
  final String requestStatus;

  const WithdrawalSubmission({
    required this.transaction,
    required this.verificationCode,
    required this.assignedAgentId,
    required this.requestStatus,
  });

  @override
  List<Object?> get props =>
      [transaction.id, verificationCode, assignedAgentId, requestStatus];
}
