import '../../core/network/dio_client.dart';
import 'agent_models.dart';

class AgentRemoteDataSource {
  final DioClient _client;

  AgentRemoteDataSource(this._client);

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
