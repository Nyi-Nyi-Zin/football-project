import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/dio_client.dart';
import 'admin_models.dart';
import 'admin_ops_models.dart';

final adminDatasourceProvider = Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSource(ref.read(dioClientProvider));
});

class AdminRemoteDataSource {
  final DioClient _client;
  final _uuid = const Uuid();

  AdminRemoteDataSource(this._client);

  Future<PaginatedUsersResponse> getUsers({
    String query = '',
    String status = '',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/admin/users',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (query.trim().isNotEmpty) 'q': query,
        if (status.trim().isNotEmpty) 'status': status,
      },
    );

    final data = (response.data['data'] as List<dynamic>)
        .map((e) => AdminUser.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = (response.data['meta'] as Map<String, dynamic>? ?? {});
    final stats = AdminUserStats.fromJson(
      response.data['stats'] as Map<String, dynamic>? ?? {},
    );

    return PaginatedUsersResponse(
      users: data,
      stats: stats,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      page: (meta['page'] as num?)?.toInt() ?? page,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
    );
  }

  Future<AdminUser> createUser({
    required String email,
    required String username,
    required String password,
    required String fullName,
    required String role,
    required String status,
    String phone = '',
    String region = '',
    String township = '',
  }) async {
    final response = await _client.dio.post(
      '/admin/users',
      data: {
        'email': email.trim(),
        'username': username.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'role': role,
        'status': status,
        if (region.trim().isNotEmpty) 'region': region.trim(),
        if (township.trim().isNotEmpty) 'township': township.trim(),
      },
    );
    return AdminUser.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AdminUser> getUserDetail(String id) async {
    final response = await _client.dio.get('/admin/users/$id');
    return AdminUser.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AdminUser> updateUserStatus({
    required String userId,
    required String status,
  }) async {
    final response = await _client.dio.patch(
      '/admin/users/$userId/status',
      data: {'status': status},
    );
    return AdminUser.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<PaginatedTransactionsResponse> getTransactions({
    String userId = '',
    String type = '',
    String status = '',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/admin/transactions',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (userId.trim().isNotEmpty) 'user_id': userId,
        if (type.trim().isNotEmpty) 'type': type,
        if (status.trim().isNotEmpty) 'status': status,
      },
    );

    final rows = (response.data['data'] as List<dynamic>)
        .map((e) => AdminTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = (response.data['meta'] as Map<String, dynamic>? ?? {});

    return PaginatedTransactionsResponse(
      transactions: rows,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      page: (meta['page'] as num?)?.toInt() ?? page,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
    );
  }

  Future<PaginatedTransactionsResponse> getWithdrawals({
    String status = '',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/admin/withdrawals',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status.trim().isNotEmpty) 'status': status,
      },
    );

    final rows = (response.data['data'] as List<dynamic>)
        .map((e) => AdminTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = (response.data['meta'] as Map<String, dynamic>? ?? {});

    return PaginatedTransactionsResponse(
      transactions: rows,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      page: (meta['page'] as num?)?.toInt() ?? page,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<AdminMatchSummary>> getMatches() async {
    final response = await _client.dio.get(
      '/matches',
      queryParameters: {'page': 1, 'limit': 100},
    );
    return (response.data['data'] as List<dynamic>)
        .map((item) => AdminMatchSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateOdds({
    required String matchId,
    required double homeOdds,
    required double drawOdds,
    required double awayOdds,
  }) async {
    await _client.dio.put('/odds', data: {
      'match_id': matchId,
      'home_odds': homeOdds,
      'draw_odds': drawOdds,
      'away_odds': awayOdds,
    });
  }

  Future<AdminTransaction> adjustBalance({
    required String userId,
    required double amount,
    required String action,
    required String reason,
    String currency = 'MMK',
  }) async {
    final response = await _client.dio.post('/admin/balance/adjust', data: {
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'action': action,
      'reason': reason,
    });
    return AdminTransaction.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<void> approveWithdrawal(String txId) async {
    await _client.dio.post('/admin/withdrawals/$txId/approve');
  }

  Future<void> rejectWithdrawal(String txId, {String reason = ''}) async {
    await _client.dio.post('/admin/withdrawals/$txId/reject', data: {
      'reason': reason,
    });
  }

  Future<AdminFinancialSummary> getFinancialSummary() async {
    final response =
        await _client.dio.get('/admin/dashboard/financial-summary');
    return AdminFinancialSummary.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<String> exportTransactionsCsv({
    String userId = '',
    String type = '',
    String status = '',
  }) async {
    final txRes = await getTransactions(
      userId: userId,
      type: type,
      status: status,
      page: 1,
      limit: 500,
    );
    final buffer = StringBuffer();
    buffer.writeln(
        'id,user_id,type,amount,currency,status,description,created_at');
    for (final tx in txRes.transactions) {
      final description = tx.description.replaceAll(',', ' ');
      buffer.writeln(
        '${tx.id},${tx.userId},${tx.type},${tx.amount},${tx.currency},${tx.status},$description,${tx.createdAt.toIso8601String()}',
      );
    }
    return buffer.toString();
  }

  Future<AdminSupportTicketsResponse> getSupportTickets({
    String status = '',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/admin/support/tickets',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    final rows = (response.data['data'] as List<dynamic>? ?? const [])
        .map(
            (item) => AdminSupportTicket.fromJson(item as Map<String, dynamic>))
        .toList();
    final meta = response.data['meta'] as Map<String, dynamic>? ?? const {};
    return AdminSupportTicketsResponse(
      tickets: rows,
      total: (meta['total'] as num?)?.toInt() ?? rows.length,
      page: (meta['page'] as num?)?.toInt() ?? page,
      lastPage: (meta['lastPage'] as num?)?.toInt() ?? 1,
    );
  }

  Future<AdminSupportTicket> updateSupportTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    final response = await _client.dio.patch(
      '/admin/support/tickets/$ticketId/status',
      data: {'status': status},
    );
    return AdminSupportTicket.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<AdminReconciliationSummary> getWalletReconciliation() async {
    final response = await _client.dio.get('/admin/wallet/reconciliation');
    return AdminReconciliationSummary.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<AdminAgentCommissionRule> getAgentCommissionRule(
      String agentId) async {
    final response = await _client.dio.get('/admin/agents/$agentId/commission');
    return AdminAgentCommissionRule.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<AdminAgentCommissionRule> updateAgentCommissionRule({
    required String agentId,
    required int depositRateBps,
    required int payoutRateBps,
    String currency = 'MMK',
  }) async {
    final response = await _client.dio.patch(
      '/admin/agents/$agentId/commission',
      data: {
        'deposit_rate_bps': depositRateBps,
        'payout_rate_bps': payoutRateBps,
        'currency': currency,
      },
    );
    return AdminAgentCommissionRule.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<PaginatedAuditLogsResponse> getAuditLogs({
    String action = '',
    String resourceType = '',
    int page = 1,
    int limit = 25,
  }) async {
    final response = await _client.dio.get(
      '/admin/audit-logs',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (action.trim().isNotEmpty) 'action': action.trim(),
        if (resourceType.trim().isNotEmpty)
          'resource_type': resourceType.trim(),
      },
    );
    final payload = response.data['data'] as Map<String, dynamic>? ?? const {};
    final rows = (payload['items'] as List<dynamic>? ?? const [])
        .map((item) => AdminAuditLog.fromJson(item as Map<String, dynamic>))
        .toList();
    return PaginatedAuditLogsResponse(
      logs: rows,
      total: (payload['total'] as num?)?.toInt() ?? rows.length,
      page: (payload['page'] as num?)?.toInt() ?? page,
      limit: (payload['limit'] as num?)?.toInt() ?? limit,
    );
  }

  Options buildSecureOptions() {
    return Options(headers: {'X-Request-Id': _uuid.v4()});
  }
}
