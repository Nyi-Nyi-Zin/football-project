import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/betting_remote_datasource.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/betting_entity.dart';

const availableLeagueFilters = <String>[
  'Premier League',
  'LaLiga',
  'Ligue 1',
  'Champions League',
  'Bundesliga',
  'Serie A',
];

final bettingDataSourceProvider = Provider<BettingRemoteDataSource>((ref) {
  return BettingRemoteDataSource(ref.read(dioClientProvider));
});

final selectedLeaguesProvider =
    StateProvider<List<String>>((_) => const ['Premier League']);

/// Null loads all available matches; otherwise the value is sent to the API.
final selectedMatchStatusProvider = StateProvider<String?>((_) => 'upcoming');
final matchesRefreshKeyProvider = StateProvider<int>((_) => 0);

final matchesProvider = FutureProvider<List<Match>>((ref) async {
  ref.watch(matchesRefreshKeyProvider);
  final leagues = ref.watch(selectedLeaguesProvider);
  final status = ref.watch(selectedMatchStatusProvider);
  final dataSource = ref.watch(bettingDataSourceProvider);
  final models = await dataSource.getMatches(
    status: status,
    leagues: leagues,
    limit: 50,
  );
  return models.map((m) => m.toEntity()).toList();
});

final myBetSlipsProvider =
    FutureProvider.autoDispose<List<BetSlip>>((ref) async {
  final ds = ref.read(bettingDataSourceProvider);
  final slips = await ds.getMyBetSlips();
  return slips.map((s) => s.toEntity()).toList();
});

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
    required String marketKey,
    required String selection,
    required double stake,
    String betType = 'single',
  }) async {
    try {
      final model = await _dataSource.placeBet(
        matchId: matchId,
        marketKey: marketKey,
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

final betCartProvider =
    StateNotifierProvider<BetCartNotifier, List<BetCartItem>>(
  (ref) => BetCartNotifier(ref),
);

class BetCartNotifier extends StateNotifier<List<BetCartItem>> {
  final Ref _ref;

  BetCartNotifier(this._ref) : super(const []);

  void toggleItem({
    required Match match,
    required Market market,
    required MarketSelection selection,
  }) {
    final existingIndex = state.indexWhere((item) => item.match.id == match.id);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      if (existing.market.key == market.key &&
          existing.selection.key == selection.key) {
        removeMatch(match.id);
        return;
      }
      final next = [...state];
      next[existingIndex] = BetCartItem(
        match: match,
        market: market,
        selection: selection,
      );
      state = next;
      return;
    }

    state = [
      ...state,
      BetCartItem(match: match, market: market, selection: selection),
    ];
  }

  void removeMatch(String matchId) {
    state = state.where((item) => item.match.id != matchId).toList();
  }

  void clear() {
    state = const [];
  }

  double get combinedOdds {
    if (state.isEmpty) return 0;
    return state.fold<double>(1, (value, item) => value * item.selection.odds);
  }

  Future<bool> placeSelections(double stake) async {
    if (state.isEmpty) return false;

    try {
      final ds = _ref.read(bettingDataSourceProvider);
      if (state.length == 1) {
        final item = state.first;
        await ds.placeBet(
          matchId: item.match.id,
          marketKey: item.market.key,
          selection: item.selection.key,
          stake: stake,
          betType: 'single',
        );
        _ref.invalidate(myBetsProvider);
      } else {
        await ds.placeBetSlip(
          stake: stake,
          legs: state
              .map((item) => {
                    'match_id': item.match.id,
                    'market_key': item.market.key,
                    'selection_key': item.selection.key,
                  })
              .toList(),
        );
        _ref.invalidate(myBetSlipsProvider);
      }

      state = const [];
      return true;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
