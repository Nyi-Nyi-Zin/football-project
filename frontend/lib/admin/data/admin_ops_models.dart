class AdminSupportTicket {
  final String id;
  final String requesterId;
  final String subject;
  final String category;
  final String priority;
  final String status;
  final String description;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminSupportTicket({
    required this.id,
    required this.requesterId,
    required this.subject,
    required this.category,
    required this.priority,
    required this.status,
    required this.description,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminSupportTicket.fromJson(Map<String, dynamic> json) {
    return AdminSupportTicket(
      id: json['id'] as String? ?? '',
      requesterId: json['requester_id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      category: json['category'] as String? ?? '',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'open',
      description: json['description'] as String? ?? '',
      assignedTo: json['assigned_to'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AdminSupportTicketsResponse {
  final List<AdminSupportTicket> tickets;
  final int total;
  final int page;
  final int lastPage;

  const AdminSupportTicketsResponse({
    required this.tickets,
    required this.total,
    required this.page,
    required this.lastPage,
  });
}

class AdminAgentCommissionRule {
  final String agentId;
  final int depositRateBps;
  final int payoutRateBps;
  final String currency;
  final bool active;

  const AdminAgentCommissionRule({
    required this.agentId,
    required this.depositRateBps,
    required this.payoutRateBps,
    required this.currency,
    required this.active,
  });

  factory AdminAgentCommissionRule.fromJson(Map<String, dynamic> json) {
    return AdminAgentCommissionRule(
      agentId: json['agent_id'] as String? ?? '',
      depositRateBps: (json['deposit_rate_bps'] as num?)?.toInt() ?? 0,
      payoutRateBps: (json['payout_rate_bps'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'MMK',
      active: json['active'] as bool? ?? true,
    );
  }
}

class AdminReconciliationSummary {
  final DateTime generatedAt;
  final int reconciledUsers;
  final int discrepancyUsers;
  final int totalTransactions;
  final double totalDeposits;
  final double totalWithdrawals;
  final double netCashFlow;
  final double totalLedgerChange;
  final int pendingWithdrawals;

  const AdminReconciliationSummary({
    required this.generatedAt,
    required this.reconciledUsers,
    required this.discrepancyUsers,
    required this.totalTransactions,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.netCashFlow,
    required this.totalLedgerChange,
    required this.pendingWithdrawals,
  });

  factory AdminReconciliationSummary.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    return AdminReconciliationSummary(
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ??
          DateTime.now(),
      reconciledUsers: (json['reconciled_users'] as num?)?.toInt() ?? 0,
      discrepancyUsers: (json['discrepancy_users'] as num?)?.toInt() ?? 0,
      totalTransactions: (totals['total_transactions'] as num?)?.toInt() ?? 0,
      totalDeposits: (totals['total_deposits'] as num?)?.toDouble() ?? 0,
      totalWithdrawals: (totals['total_withdrawals'] as num?)?.toDouble() ?? 0,
      netCashFlow: (totals['net_cash_flow'] as num?)?.toDouble() ?? 0,
      totalLedgerChange:
          (totals['total_ledger_change'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals: (totals['pending_withdrawals'] as num?)?.toInt() ?? 0,
    );
  }
}
