import '../../core/network/dio_client.dart';
import 'agent_models.dart';

class AgentRemoteDataSource {
  final DioClient _client;

  AgentRemoteDataSource(this._client);

  Future<AgentDashboardSummary> getDashboardSummary() async {
    final response = await _client.dio.get('/agent/dashboard');
    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    return AgentDashboardSummary.fromJson(data);
  }

  Future<AgentEarningsSummary> getEarnings({int days = 30}) async {
    final response = await _client.dio.get(
      '/agent/earnings',
      queryParameters: {'days': days.clamp(1, 90)},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    return AgentEarningsSummary.fromJson(data);
  }

  Future<AgentCustomerActivity> getCustomerActivity(String customerId) async {
    final response =
        await _client.dio.get('/agent/customers/$customerId/activity');
    final data = response.data['data'] as Map<String, dynamic>? ?? const {};
    return AgentCustomerActivity.fromJson(data);
  }

  Future<List<AgentCustomerSummary>> getCustomers({
    String query = '',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/agent/customers',
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'page': page,
        'limit': limit,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => AgentCustomerSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AgentWithdrawalItem>> getAssignedWithdrawals({
    String status = 'pending',
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/agent/withdrawals',
      queryParameters: {
        'status': status,
        'page': page,
        'limit': limit,
      },
    );
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => AgentWithdrawalItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> verifyWithdrawalCode(String code) async {
    await _client.dio.post(
      '/agent/withdrawals/verify',
      data: {'code': code.trim().toUpperCase()},
    );
  }

  Future<List<AgentSupportTicket>> getSupportTickets({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get(
      '/support/tickets',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => AgentSupportTicket.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AgentSupportTicket> createSupportTicket({
    required String subject,
    required String category,
    required String priority,
    required String description,
  }) async {
    final response = await _client.dio.post(
      '/support/tickets',
      data: {
        'subject': subject.trim(),
        'category': category.trim(),
        'priority': priority,
        'description': description.trim(),
      },
    );
    return AgentSupportTicket.fromJson(
      response.data['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<List<AgentSupportMessage>> getSupportMessages(String ticketId) async {
    final response =
        await _client.dio.get('/support/tickets/$ticketId/messages');
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data
        .map((e) => AgentSupportMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AgentSupportMessage> addSupportMessage({
    required String ticketId,
    required String body,
  }) async {
    final response = await _client.dio.post(
      '/support/tickets/$ticketId/messages',
      data: {'body': body.trim()},
    );
    return AgentSupportMessage.fromJson(
      response.data['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<AgentSecuritySession> getSecuritySession() async {
    final response = await _client.dio.get('/agent/security/sessions');
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return AgentSecuritySession.fromJson(
      data.isEmpty ? const {} : data.first as Map<String, dynamic>,
    );
  }

  Future<void> changeSecurityPin({
    String? currentPin,
    required String newPin,
  }) async {
    await _client.dio.post(
      '/agent/security/pin',
      data: {
        if (currentPin != null && currentPin.trim().isNotEmpty)
          'current_pin': currentPin.trim(),
        'new_pin': newPin.trim(),
      },
    );
  }

  Future<void> logoutAllDevices() async {
    await _client.dio.post('/agent/security/logout-all');
  }
}
