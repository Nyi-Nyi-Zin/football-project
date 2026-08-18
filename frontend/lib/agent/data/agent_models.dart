import '../../features/payment/data/models/payment_model.dart';
import '../../features/payment/domain/entities/payment_entity.dart';

class AgentWithdrawalItem {
  final String requestId;
  final String transactionId;
  final String customerId;
  final String customerName;
  final String agentId;
  final String requestStatus;
  final String transactionStatus;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const AgentWithdrawalItem({
    required this.requestId,
    required this.transactionId,
    required this.customerId,
    this.customerName = '',
    required this.agentId,
    required this.requestStatus,
    required this.transactionStatus,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.expiresAt,
  });

  factory AgentWithdrawalItem.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>? ?? const {};
    final tx = json['transaction'] as Map<String, dynamic>? ?? const {};
    return AgentWithdrawalItem(
      requestId: request['id'] as String? ?? '',
      transactionId: tx['id'] as String? ?? '',
      customerId: request['customer_id'] as String? ?? '',
      customerName: request['customer_name'] as String? ?? '',
      agentId: request['agent_id'] as String? ?? '',
      requestStatus: request['status'] as String? ?? 'pending',
      transactionStatus: tx['status'] as String? ?? 'pending',
      amount: (tx['amount'] as num?)?.toDouble() ?? 0,
      currency: tx['currency'] as String? ?? 'USD',
      createdAt: DateTime.tryParse(tx['created_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(request['expires_at'] as String? ?? ''),
    );
  }
}

class AgentCustomerSummary {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String phone;
  final String status;
  final double balance;
  final DateTime? createdAt;

  const AgentCustomerSummary({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.status,
    required this.balance,
    required this.createdAt,
  });

  factory AgentCustomerSummary.fromJson(Map<String, dynamic> json) {
    return AgentCustomerSummary(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class AgentCustomerActivity {
  final List<Transaction> transactions;
  final List<AgentWithdrawalItem> withdrawals;

  const AgentCustomerActivity({
    required this.transactions,
    required this.withdrawals,
  });

  factory AgentCustomerActivity.fromJson(Map<String, dynamic> json) {
    return AgentCustomerActivity(
      transactions: (json['transactions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((json) => TransactionModel.fromJson(json).toEntity())
          .toList(),
      withdrawals: (json['withdrawals'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentWithdrawalItem.fromJson)
          .toList(),
    );
  }
}

class AgentDashboardSummary {
  final double availableBalance;
  final double reservedBalance;
  final String currency;
  final int pendingPayouts;
  final double todayDeposits;
  final double todayPayouts;
  final int recentTransactions;

  const AgentDashboardSummary({
    required this.availableBalance,
    required this.reservedBalance,
    required this.currency,
    required this.pendingPayouts,
    required this.todayDeposits,
    required this.todayPayouts,
    required this.recentTransactions,
  });

  factory AgentDashboardSummary.fromJson(Map<String, dynamic> json) {
    return AgentDashboardSummary(
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      reservedBalance: (json['reserved_balance'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'MMK',
      pendingPayouts: (json['pending_payouts'] as num?)?.toInt() ?? 0,
      todayDeposits: (json['today_deposits'] as num?)?.toDouble() ?? 0,
      todayPayouts: (json['today_payouts'] as num?)?.toDouble() ?? 0,
      recentTransactions: (json['recent_transactions'] as num?)?.toInt() ?? 0,
    );
  }
}
