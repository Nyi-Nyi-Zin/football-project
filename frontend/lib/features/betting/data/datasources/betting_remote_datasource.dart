import '../../../../core/network/dio_client.dart';
import '../models/betting_model.dart';

class BettingRemoteDataSource {
  final DioClient _client;

  BettingRemoteDataSource(this._client);

  Future<List<MatchModel>> getMatches({
    String? sport,
    String? status,
    List<String>? leagues,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get('/matches', queryParameters: {
      'page': page,
      'limit': limit,
      if (sport != null) 'sport': sport,
      if (status != null) 'status': status,
      if (leagues != null && leagues.isNotEmpty) 'leagues': leagues.join(','),
    });
    final data = response.data['data'] as List;
    return data
        .map((e) => MatchModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BetModel> placeBet({
    required String matchId,
    required String marketKey,
    required String selection,
    required double stake,
    required String betType,
  }) async {
    final response = await _client.dio.post('/bets', data: {
      'match_id': matchId,
      'market_key': marketKey,
      'selection': selection,
      'stake': stake,
      'bet_type': betType,
    });
    return BetModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<BetSlipModel> placeBetSlip({
    required double stake,
    required List<Map<String, dynamic>> legs,
  }) async {
    final response = await _client.dio.post('/bets/slips', data: {
      'stake': stake,
      'legs': legs,
    });
    return BetSlipModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<BetSlipModel>> getMyBetSlips({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get('/bets/slips/my', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
    });
    final data = response.data['data'] as List;
    return data
        .map((e) => BetSlipModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BetModel>> getMyBets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.dio.get('/bets/my', queryParameters: {
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
    });
    final data = response.data['data'] as List;
    return data
        .map((e) => BetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BetModel> getBet(String id) async {
    final response = await _client.dio.get('/bets/$id');
    return BetModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> cancelBet(String id) async {
    await _client.dio.delete('/bets/$id');
  }
}
