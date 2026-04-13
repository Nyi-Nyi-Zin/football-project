import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/websocket.dart';
import '../../data/datasources/odds_remote_datasource.dart';
import '../../domain/entities/odds_entity.dart';

final oddsDatasourceProvider = Provider<OddsRemoteDataSource>((ref) {
  return OddsRemoteDataSource(
    ref.read(dioClientProvider),
    ref.read(webSocketServiceProvider),
  );
});

// Stream provider for Live Odds WebSocket
final liveOddsProvider = StreamProvider.autoDispose<OddsUpdateEvent>((ref) {
  final ds = ref.read(oddsDatasourceProvider);
  ref.onDispose(() {
    ds.disconnect();
  });
  return ds.connectLiveOdds();
});

// Maintains the current active odds mapped by matchId
final matchOddsStateProvider = StateNotifierProvider<MatchOddsNotifier, Map<String, OddsUpdateEvent>>((ref) {
  return MatchOddsNotifier(ref);
});

class MatchOddsNotifier extends StateNotifier<Map<String, OddsUpdateEvent>> {
  final Ref _ref;

  MatchOddsNotifier(this._ref) : super({}) {
    // Listen to live odds updates and maintain a state map
    _ref.listen<AsyncValue<OddsUpdateEvent>>(liveOddsProvider, (previous, next) {
      next.whenData((update) {
        state = {
          ...state,
          update.matchId: update,
        };
      });
    });
  }

  // Initial fetch for a specific match
  Future<void> fetchInitialOdds(String matchId) async {
    try {
      final ds = _ref.read(oddsDatasourceProvider);
      final model = await ds.getMatchOdds(matchId);
      final entity = model.toEntity();
      
      state = {
        ...state,
        matchId: OddsUpdateEvent(
          matchId: matchId,
          homeOdds: entity.homeOdds,
          awayOdds: entity.awayOdds,
          drawOdds: entity.drawOdds,
        ),
      };
    } catch (e) {
      // Handle error gently
    }
  }
}
