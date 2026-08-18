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

class AgentEarningsSummary {
  final int periodDays;
  final DateTime from;
  final DateTime to;
  final String currency;
  final int depositCount;
  final double depositAmount;
  final int payoutCount;
  final double payoutAmount;
  final double netSettlement;
  final int pendingPayoutCount;

  const AgentEarningsSummary({
    required this.periodDays,
    required this.from,
    required this.to,
    required this.currency,
    required this.depositCount,
    required this.depositAmount,
    required this.payoutCount,
    required this.payoutAmount,
    required this.netSettlement,
    required this.pendingPayoutCount,
  });

  factory AgentEarningsSummary.fromJson(Map<String, dynamic> json) {
    return AgentEarningsSummary(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 30,
      from: DateTime.tryParse(json['from'] as String? ?? '') ?? DateTime.now(),
      to: DateTime.tryParse(json['to'] as String? ?? '') ?? DateTime.now(),
      currency: json['currency'] as String? ?? 'MMK',
      depositCount: (json['deposit_count'] as num?)?.toInt() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      payoutCount: (json['payout_count'] as num?)?.toInt() ?? 0,
      payoutAmount: (json['payout_amount'] as num?)?.toDouble() ?? 0,
      netSettlement: (json['net_settlement'] as num?)?.toDouble() ?? 0,
      pendingPayoutCount: (json['pending_payout_count'] as num?)?.toInt() ?? 0,
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

class AgentSupportTicket {
  final String id;
  final String requesterId;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String description;
  final String? assignedTo;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgentSupportTicket({
    required this.id,
    required this.requesterId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.assignedTo,
    required this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgentSupportTicket.fromJson(Map<String, dynamic> json) {
    return AgentSupportTicket(
      id: json['id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'open',
      description: json['description'] as String? ?? '',
      assignedTo: json['assigned_to'] as String?,
      resolvedAt: DateTime.tryParse(json['resolved_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AgentSupportMessage {
  final String id;
  final String ticketId;
  final String authorId;
  final String authorRole;
  final String body;
  final DateTime createdAt;

  const AgentSupportMessage({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.authorRole,
    required this.body,
    required this.createdAt,
  });

  factory AgentSupportMessage.fromJson(Map<String, dynamic> json) {
    return AgentSupportMessage(
      id: json['id'] as String? ?? '',
      ticketId: json['ticket_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorRole: json['author_role'] as String? ?? 'user',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AgentSecuritySession {
  final String sessionId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool isCurrent;
  final bool revocable;

  const AgentSecuritySession({
    required this.sessionId,
    required this.issuedAt,
    required this.expiresAt,
    required this.isCurrent,
    required this.revocable,
  });

  factory AgentSecuritySession.fromJson(Map<String, dynamic> json) {
    return AgentSecuritySession(
      sessionId: json['session_id'] as String? ?? '',
      issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      isCurrent: json['is_current'] as bool? ?? true,
      revocable: json['revocable'] as bool? ?? true,
    );
  }
}

class AgentReconciliationReport {
  final DateTime generatedAt;
  final DateTime from;
  final DateTime to;
  final String agentId;
  final String currency;
  final double walletBalance;
  final double reservedBalance;
  final double availableBalance;
  final double ledgerChange;
  final double difference;
  final bool reconciled;
  final int depositCount;
  final double depositAmount;
  final int payoutCount;
  final double payoutAmount;
  final double netSettlement;
  final int pendingPayouts;
  final int transactionCount;

  const AgentReconciliationReport({
    required this.generatedAt,
    required this.from,
    required this.to,
    required this.agentId,
    required this.currency,
    required this.walletBalance,
    required this.reservedBalance,
    required this.availableBalance,
    required this.ledgerChange,
    required this.difference,
    required this.reconciled,
    required this.depositCount,
    required this.depositAmount,
    required this.payoutCount,
    required this.payoutAmount,
    required this.netSettlement,
    required this.pendingPayouts,
    required this.transactionCount,
  });

  factory AgentReconciliationReport.fromJson(Map<String, dynamic> json) {
    return AgentReconciliationReport(
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
          DateTime.now(),
      from: DateTime.tryParse(json['from'] as String? ?? '') ?? DateTime.now(),
      to: DateTime.tryParse(json['to'] as String? ?? '') ?? DateTime.now(),
      agentId: json['agent_id'] as String? ?? '',
      currency: json['currency'] as String? ?? 'MMK',
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0,
      reservedBalance: (json['reserved_balance'] as num?)?.toDouble() ?? 0,
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      ledgerChange: (json['ledger_change'] as num?)?.toDouble() ?? 0,
      difference: (json['difference'] as num?)?.toDouble() ?? 0,
      reconciled: json['reconciled'] as bool? ?? false,
      depositCount: (json['deposit_count'] as num?)?.toInt() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      payoutCount: (json['payout_count'] as num?)?.toInt() ?? 0,
      payoutAmount: (json['payout_amount'] as num?)?.toDouble() ?? 0,
      netSettlement: (json['net_settlement'] as num?)?.toDouble() ?? 0,
      pendingPayouts: (json['pending_payouts'] as num?)?.toInt() ?? 0,
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AgentCommissionStatement {
  final AgentEarningsSummary earnings;
  final int depositRateBps;
  final int payoutRateBps;
  final double depositRatePercent;
  final double payoutRatePercent;
  final double depositCommission;
  final double payoutCommission;
  final double commissionAmount;
  final double grossSettlement;
  final double netAfterCommission;

  const AgentCommissionStatement({
    required this.earnings,
    required this.depositRateBps,
    required this.payoutRateBps,
    required this.depositRatePercent,
    required this.payoutRatePercent,
    required this.depositCommission,
    required this.payoutCommission,
    required this.commissionAmount,
    required this.grossSettlement,
    required this.netAfterCommission,
  });

  factory AgentCommissionStatement.fromJson(Map<String, dynamic> json) {
    return AgentCommissionStatement(
      earnings: AgentEarningsSummary.fromJson(json),
      depositRateBps: (json['deposit_rate_bps'] as num?)?.toInt() ?? 0,
      payoutRateBps: (json['payout_rate_bps'] as num?)?.toInt() ?? 0,
      depositRatePercent:
          (json['deposit_rate_percent'] as num?)?.toDouble() ?? 0,
      payoutRatePercent: (json['payout_rate_percent'] as num?)?.toDouble() ?? 0,
      depositCommission: (json['deposit_commission'] as num?)?.toDouble() ?? 0,
      payoutCommission: (json['payout_commission'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      grossSettlement: (json['gross_settlement'] as num?)?.toDouble() ?? 0,
      netAfterCommission:
          (json['net_after_commission'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AgentTwoFactorStatus {
  final bool enabled;

  const AgentTwoFactorStatus({required this.enabled});

  factory AgentTwoFactorStatus.fromJson(Map<String, dynamic> json) {
    return AgentTwoFactorStatus(enabled: json['enabled'] as bool? ?? false);
  }
}

class AgentTwoFactorEnrollment {
  final String secret;
  final String otpauthUrl;
  final bool enabled;

  const AgentTwoFactorEnrollment({
    required this.secret,
    required this.otpauthUrl,
    required this.enabled,
  });

  factory AgentTwoFactorEnrollment.fromJson(Map<String, dynamic> json) {
    return AgentTwoFactorEnrollment(
      secret: json['secret'] as String? ?? '',
      otpauthUrl: json['otpauth_url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}
