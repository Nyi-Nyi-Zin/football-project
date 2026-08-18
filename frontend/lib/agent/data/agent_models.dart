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
