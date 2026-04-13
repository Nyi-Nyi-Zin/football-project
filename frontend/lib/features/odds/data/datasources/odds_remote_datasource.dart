import '../../../../core/network/dio_client.dart';
import '../../../../core/network/websocket.dart';
import '../models/odds_model.dart';
import '../../domain/entities/odds_entity.dart';

class OddsRemoteDataSource {
  final DioClient _client;
  final WebSocketService _wsService;

  OddsRemoteDataSource(this._client, this._wsService);

  Future<OddsModel> getMatchOdds(String matchId) async {
    final response = await _client.dio.get('/odds/$matchId');
    return OddsModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Stream<OddsUpdateEvent> connectLiveOdds() {
    return _wsService.connect().map((data) {
      if (data['type'] == 'ODDS_UPDATE') {
        final payload = data['payload'] as Map<String, dynamic>;
        return OddsUpdateEvent(
          matchId: payload['matchId'] as String,
          homeOdds: (payload['homeOdds'] as num).toDouble(),
          awayOdds: (payload['awayOdds'] as num).toDouble(),
          drawOdds: payload['drawOdds'] != null ? (payload['drawOdds'] as num).toDouble() : null,
        );
      }
      throw Exception('Unknown message type');
    }).handleError((e) {
      print('WebSocket error: $e');
    });
  }

  void disconnect() {
    _wsService.disconnect();
  }
}
