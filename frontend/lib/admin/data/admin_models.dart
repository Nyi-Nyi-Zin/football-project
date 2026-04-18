class AdminUserStats {
  final int totalUsers;
  final int activeUsers;
  final int suspendedUsers;

  const AdminUserStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.suspendedUsers,
  });

  factory AdminUserStats.fromJson(Map<String, dynamic> json) {
    return AdminUserStats(
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      activeUsers: (json['active_users'] as num?)?.toInt() ?? 0,
      suspendedUsers: (json['suspended_users'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminUser {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final String status;
  final double balance;
  final DateTime createdAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.status,
    required this.balance,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'active',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AdminTransaction {
  final String id;
  final String userId;
  final String type;
  final double amount;
  final String currency;
  final String status;
  final String description;
  final String reference;
  final DateTime createdAt;

  const AdminTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.description,
    required this.reference,
    required this.createdAt,
  });

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? 'pending',
      description: json['description'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AdminFinancialSummary {
  final int totalTransactions;
  final double totalDeposits;
  final double totalWithdrawals;
  final int pendingWithdrawals;

  const AdminFinancialSummary({
    required this.totalTransactions,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.pendingWithdrawals,
  });

  factory AdminFinancialSummary.fromJson(Map<String, dynamic> json) {
    return AdminFinancialSummary(
      totalTransactions: (json['total_transactions'] as num?)?.toInt() ?? 0,
      totalDeposits: (json['total_deposits'] as num?)?.toDouble() ?? 0,
      totalWithdrawals: (json['total_withdrawals'] as num?)?.toDouble() ?? 0,
      pendingWithdrawals: (json['pending_withdrawals'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaginatedUsersResponse {
  final List<AdminUser> users;
  final AdminUserStats stats;
  final int total;
  final int page;
  final int lastPage;

  const PaginatedUsersResponse({
    required this.users,
    required this.stats,
    required this.total,
    required this.page,
    required this.lastPage,
  });
}

class PaginatedTransactionsResponse {
  final List<AdminTransaction> transactions;
  final int total;
  final int page;
  final int lastPage;

  const PaginatedTransactionsResponse({
    required this.transactions,
    required this.total,
    required this.page,
    required this.lastPage,
  });
}
