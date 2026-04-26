import '../../domain/entities/betting_entity.dart';

class MatchModel {
  final String id;
  final String sport;
  final String league;
  final String homeTeam;
  final String awayTeam;
  final DateTime startTime;
  final String status;
  final int? homeScore;
  final int? awayScore;
  final List<MarketModel> markets;

  const MatchModel({
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

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] as String,
      sport: json['sport'] as String,
      league: json['league'] as String,
      homeTeam: json['home_team'] as String,
      awayTeam: json['away_team'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      status: json['status'] as String? ?? 'upcoming',
      homeScore: json['home_score'] as int?,
      awayScore: json['away_score'] as int?,
      markets: (json['markets'] as List<dynamic>? ?? const [])
          .map((e) => MarketModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Match toEntity() => Match(
        id: id,
        sport: sport,
        league: league,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        startTime: startTime,
        status: status,
        homeScore: homeScore,
        awayScore: awayScore,
        markets: markets.map((m) => m.toEntity()).toList(),
      );
}

class MarketModel {
  final String key;
  final String name;
  final List<MarketSelectionModel> selections;

  const MarketModel({
    required this.key,
    required this.name,
    required this.selections,
  });

  factory MarketModel.fromJson(Map<String, dynamic> json) {
    return MarketModel(
      key: json['key'] as String,
      name: json['name'] as String,
      selections: (json['selections'] as List<dynamic>? ?? const [])
          .map((e) => MarketSelectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Market toEntity() => Market(
        key: key,
        name: name,
        selections: selections.map((s) => s.toEntity()).toList(),
      );
}

class MarketSelectionModel {
  final String key;
  final String label;
  final double odds;

  const MarketSelectionModel({
    required this.key,
    required this.label,
    required this.odds,
  });

  factory MarketSelectionModel.fromJson(Map<String, dynamic> json) {
    return MarketSelectionModel(
      key: json['key'] as String,
      label: json['label'] as String,
      odds: (json['odds'] as num).toDouble(),
    );
  }

  MarketSelection toEntity() => MarketSelection(
        key: key,
        label: label,
        odds: odds,
      );
}

class BetModel {
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
  final MatchModel? match;

  const BetModel({
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

  factory BetModel.fromJson(Map<String, dynamic> json) {
    return BetModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      matchId: json['match_id'] as String,
      betType: json['bet_type'] as String,
      marketKey: json['market_key'] as String? ?? 'match_result',
      selection: json['selection'] as String,
      selectionLabel: json['selection_label'] as String? ?? json['selection'] as String,
      odds: (json['odds'] as num).toDouble(),
      stake: (json['stake'] as num).toDouble(),
      potentialPayout: (json['potential_payout'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      match: json['match'] != null
          ? MatchModel.fromJson(json['match'] as Map<String, dynamic>)
          : null,
    );
  }

  Bet toEntity() => Bet(
        id: id,
        userId: userId,
        matchId: matchId,
        betType: betType,
        marketKey: marketKey,
        selection: selection,
        selectionLabel: selectionLabel,
        odds: odds,
        stake: stake,
        potentialPayout: potentialPayout,
        status: status,
        createdAt: createdAt,
        match: match?.toEntity(),
      );
}

class BetSlipModel {
  final String id;
  final String userId;
  final String betType;
  final double stake;
  final double combinedOdds;
  final double potentialPayout;
  final String status;
  final DateTime createdAt;
  final List<BetLegModel> legs;

  const BetSlipModel({
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

  factory BetSlipModel.fromJson(Map<String, dynamic> json) {
    return BetSlipModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      betType: json['bet_type'] as String,
      stake: (json['stake'] as num).toDouble(),
      combinedOdds: (json['combined_odds'] as num).toDouble(),
      potentialPayout: (json['potential_payout'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      legs: (json['legs'] as List<dynamic>? ?? const [])
          .map((e) => BetLegModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  BetSlip toEntity() => BetSlip(
        id: id,
        userId: userId,
        betType: betType,
        stake: stake,
        combinedOdds: combinedOdds,
        potentialPayout: potentialPayout,
        status: status,
        createdAt: createdAt,
        legs: legs.map((l) => l.toEntity()).toList(),
      );
}

class BetLegModel {
  final String id;
  final String slipId;
  final String matchId;
  final String marketKey;
  final String selectionKey;
  final String selectionLabel;
  final double odds;
  final MatchModel? match;

  const BetLegModel({
    required this.id,
    required this.slipId,
    required this.matchId,
    required this.marketKey,
    required this.selectionKey,
    required this.selectionLabel,
    required this.odds,
    this.match,
  });

  factory BetLegModel.fromJson(Map<String, dynamic> json) {
    return BetLegModel(
      id: json['id'] as String,
      slipId: json['slip_id'] as String,
      matchId: json['match_id'] as String,
      marketKey: json['market_key'] as String,
      selectionKey: json['selection_key'] as String,
      selectionLabel: json['selection_label'] as String,
      odds: (json['odds'] as num).toDouble(),
      match: json['match'] != null
          ? MatchModel.fromJson(json['match'] as Map<String, dynamic>)
          : null,
    );
  }

  BetLeg toEntity() => BetLeg(
        id: id,
        slipId: slipId,
        matchId: matchId,
        marketKey: marketKey,
        selectionKey: selectionKey,
        selectionLabel: selectionLabel,
        odds: odds,
        match: match?.toEntity(),
      );
}
