import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/betting_remote_datasource.dart';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/betting_entity.dart';
import '../../../odds/domain/entities/odds_entity.dart';
import '../../../responsible_gaming/presentation/providers/responsible_gaming_provider.dart';

/// Replaces only the 1X2 selection price supplied by the live odds stream.
/// Other markets remain unchanged because the stream currently carries only
/// home/draw/away odds.
MarketSelection mergeLiveSelection(
  Market market,
  MarketSelection selection,
  OddsUpdateEvent? update,
) {
  if (update == null || market.key != 'match_result') {
    return selection;
  }

  final liveOdds = switch (selection.key) {
    'w1' => update.homeOdds,
    'x' => update.drawOdds,
    'w2' => update.awayOdds,
    _ => null,
  };

  if (liveOdds == null || liveOdds <= 1) {
    return selection;
  }

  return MarketSelection(
    key: selection.key,
    label: selection.label,
    odds: liveOdds,
  );
}

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

// Empty means all leagues currently available from the backend provider.
final selectedLeaguesProvider =
    StateProvider<List<String>>((_) => const <String>[]);

/// Null loads all available matches; otherwise the value is sent to the API.
final selectedMatchStatusProvider = StateProvider<String?>((_) => 'upcoming');
final matchSearchQueryProvider = StateProvider<String>((_) => '');
final favoriteMatchIdsProvider =
    StateNotifierProvider<FavoriteMatchesNotifier, Set<String>>((ref) {
  return FavoriteMatchesNotifier();
});

class FavoriteMatchesNotifier extends StateNotifier<Set<String>> {
  static const _storageKey = 'cloud9_favorite_match_ids';
  static const _storage = FlutterSecureStorage();

  FavoriteMatchesNotifier() : super(const <String>{}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;
      final ids =
          (jsonDecode(raw) as List<dynamic>).whereType<String>().toSet();
      state = ids;
    } catch (_) {
      state = const <String>{};
    }
  }

  Future<void> toggle(String matchId) async {
    final next = {...state};
    if (!next.add(matchId)) next.remove(matchId);
    state = next;
    await _storage.write(key: _storageKey, value: jsonEncode(next.toList()));
  }
}

final matchesRefreshKeyProvider = StateProvider<int>((_) => 0);

/// Refreshes match status and score data while the sportsbook screen is open.
final matchAutoRefreshProvider = Provider.autoDispose<void>((ref) {
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidate(matchesProvider);
  });
  ref.onDispose(timer.cancel);
});

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

final betDetailProvider =
    FutureProvider.autoDispose.family<Bet, String>((ref, betId) async {
  final model = await ref.read(bettingDataSourceProvider).getBet(betId);
  return model.toEntity();
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
  final Uuid _uuid = const Uuid();
  String? _activeIdempotencyKey;
  String? _lastError;

  String? get lastError => _lastError;

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
    _activeIdempotencyKey = null;
    _lastError = null;
  }

  /// Accepts the latest live 1X2 prices for selections already in the slip.
  void acceptLiveOdds(Map<String, OddsUpdateEvent> updates) {
    state = state.map((item) {
      final refreshed = mergeLiveSelection(
        item.market,
        item.selection,
        updates[item.match.id],
      );
      if (refreshed == item.selection) {
        return item;
      }
      return BetCartItem(
        match: item.match,
        market: item.market,
        selection: refreshed,
      );
    }).toList();
  }

  double get combinedOdds {
    if (state.isEmpty) return 0;
    return state.fold<double>(1, (value, item) => value * item.selection.odds);
  }

  Future<bool> placeSelections(double stake) async {
    if (state.isEmpty) {
      _lastError = 'Select at least one match before placing a bet.';
      return false;
    }

    _lastError = null;
    final gamingSettings = _ref.read(responsibleGamingProvider).valueOrNull;
    if (gamingSettings != null) {
      final limitError = gamingSettings.validateStake(
        stake: stake,
        todayStake: _todayStake(),
      );
      if (limitError != null) {
        _lastError = limitError;
        return false;
      }
    }
    final idempotencyKey = _activeIdempotencyKey ??= _uuid.v4();
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
          idempotencyKey: idempotencyKey,
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
          idempotencyKey: idempotencyKey,
        );
        _ref.invalidate(myBetSlipsProvider);
      }

      state = const [];
      _activeIdempotencyKey = null;
      return true;
    } on DioException catch (error) {
      _lastError = _betErrorMessage(error);
      return false;
    } catch (_) {
      _lastError = 'Unable to place the bet. Please try again.';
      return false;
    }
  }

  double _todayStake() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final bets = _ref.read(myBetsProvider).valueOrNull ?? const <Bet>[];
    final slips =
        _ref.read(myBetSlipsProvider).valueOrNull ?? const <BetSlip>[];
    final betStake = bets
        .where((bet) => bet.createdAt.toLocal().isAfter(startOfDay))
        .fold<double>(0, (total, bet) => total + bet.stake);
    final slipStake = slips
        .where((slip) => slip.createdAt.toLocal().isAfter(startOfDay))
        .fold<double>(0, (total, slip) => total + slip.stake);
    return betStake + slipStake;
  }

  String _betErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final apiError = data['error'];
      if (apiError is Map && apiError['message'] is String) {
        return apiError['message'] as String;
      }
      if (data['message'] is String) return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please try again.';
    }
    return 'Unable to place the bet. Please try again.';
  }
}
