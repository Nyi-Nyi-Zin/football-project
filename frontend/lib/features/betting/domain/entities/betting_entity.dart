import 'package:equatable/equatable.dart';

class Match extends Equatable {
  final String id;
  final String sport;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final DateTime startTime;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final List<Market> markets;

  const Match({
    required this.id,
    required this.sport,
    required this.league,
    required this.homeTeam,
    required this.awayTeam,
    required this.startTime,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.markets = const [],
  });

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isFinished => status == 'finished';

  @override
  List<Object?> get props => [id];
}

class Market extends Equatable {
  final String key;
  final String name;
  final List<MarketSelection> selections;

  const Market({
    required this.key,
    required this.name,
    required this.selections,
  });

  @override
  List<Object?> get props => [key, name, selections];
}

class MarketSelection extends Equatable {
  final String key;
  final String label;
  final double odds;

  const MarketSelection({
    required this.key,
    required this.label,
    required this.odds,
  });

  @override
  List<Object?> get props => [key, label, odds];
}

class Bet extends Equatable {
  final String id;
  final String userId;
  final String matchId;
  final String betType;
  final String marketKey;
  final String selection;
  final String selectionLabel;
  final double odds;
  final double stake;
  final double potentialPayout;
  final String status;
  final DateTime createdAt;
  final Match? match;

  const Bet({
    required this.id,
    required this.userId,
    required this.matchId,
    required this.betType,
    required this.marketKey,
    required this.selection,
    required this.selectionLabel,
    required this.odds,
    required this.stake,
    required this.potentialPayout,
    required this.status,
    required this.createdAt,
    this.match,
  });

  bool get isPending => status == 'pending' || status == 'active';
  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
  bool get isCancelled => status == 'cancelled';
  bool get isCashedOut => status == 'settled';

  @override
  List<Object?> get props => [id];
}

class BetOdds extends Equatable {
  final String matchId;
  final double homeOdds;
  final double awayOdds;
  final double drawOdds;
  final DateTime? timestamp;

  const BetOdds({
    required this.matchId,
    required this.homeOdds,
    required this.awayOdds,
    required this.drawOdds,
    this.timestamp,
  });

  @override
  List<Object?> get props => [matchId, homeOdds, awayOdds, drawOdds];
}

class BetSlip extends Equatable {
  final String id;
  final String userId;
  final String betType;
  final double stake;
  final double combinedOdds;
  final double potentialPayout;
  final String status;
  final DateTime createdAt;
  final List<BetLeg> legs;

  const BetSlip({
    required this.id,
    required this.userId,
    required this.betType,
    required this.stake,
    required this.combinedOdds,
    required this.potentialPayout,
    required this.status,
    required this.createdAt,
    required this.legs,
  });

  @override
  List<Object?> get props => [id, userId, betType, createdAt];
}

class BetLeg extends Equatable {
  final String id;
  final String slipId;
  final String matchId;
  final String marketKey;
  final String selectionKey;
  final String selectionLabel;
  final double odds;
  final Match? match;

  const BetLeg({
    required this.id,
    required this.slipId,
    required this.matchId,
    required this.marketKey,
    required this.selectionKey,
    required this.selectionLabel,
    required this.odds,
    this.match,
  });

  @override
  List<Object?> get props => [id, slipId, matchId, marketKey, selectionKey, odds];
}

class BetCartItem extends Equatable {
  final Match match;
  final Market market;
  final MarketSelection selection;

  const BetCartItem({
    required this.match,
    required this.market,
    required this.selection,
  });

  String get uniqueKey => '${match.id}:${market.key}:${selection.key}';

  @override
  List<Object?> get props => [match.id, market.key, selection.key];
}
