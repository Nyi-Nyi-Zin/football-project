import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/betting_remote_datasource.dart';
import '../../domain/entities/betting_entity.dart';

final bettingDataSourceProvider = Provider<BettingRemoteDataSource>((ref) {
  return BettingRemoteDataSource(ref.read(dioClientProvider));
});

// --- Matches provider ---

final matchesProvider =
    StateNotifierProvider<MatchesNotifier, AsyncValue<List<Match>>>((ref) {
  return MatchesNotifier(ref.read(bettingDataSourceProvider));
});

class MatchesNotifier extends StateNotifier<AsyncValue<List<Match>>> {
  final BettingRemoteDataSource _dataSource;

  MatchesNotifier(this._dataSource) : super(const AsyncLoading()) {
    loadMatches();
  }

  Future<void> loadMatches({String? sport, String? status}) async {
    state = const AsyncLoading();
    try {
      final models = await _dataSource.getMatches(sport: sport, status: status);
      state = AsyncData(models.map((m) => m.toEntity()).toList());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() => loadMatches();
}

// --- My Bets provider ---

final myBetsProvider =
    StateNotifierProvider<MyBetsNotifier, AsyncValue<List<Bet>>>((ref) {
  return MyBetsNotifier(ref.read(bettingDataSourceProvider));
});

class MyBetsNotifier extends StateNotifier<AsyncValue<List<Bet>>> {
  final BettingRemoteDataSource _dataSource;

  MyBetsNotifier(this._dataSource) : super(const AsyncLoading()) {
    loadBets();
  }

  Future<void> loadBets({String? status}) async {
    state = const AsyncLoading();
    try {
      final models = await _dataSource.getMyBets(status: status);
      state = AsyncData(models.map((b) => b.toEntity()).toList());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<Bet?> placeBet({
    required String matchId,
    required String selection,
    required double stake,
    String betType = 'single',
  }) async {
    try {
      final model = await _dataSource.placeBet(
        matchId: matchId,
        selection: selection,
        stake: stake,
        betType: betType,
      );
      final bet = model.toEntity();
      // Add to list
      final current = state.valueOrNull ?? [];
      state = AsyncData([bet, ...current]);
      return bet;
    } catch (e) {
      return null;
    }
  }

  Future<bool> cancelBet(String betId) async {
    try {
      await _dataSource.cancelBet(betId);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((b) => b.id != betId).toList());
      return true;
    } catch (e) {
      return false;
    }
  }
}
