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
}
