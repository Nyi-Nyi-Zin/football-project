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
      );
}

class BetModel {
  final String id;
  final String userId;
  final String matchId;
  final String betType;
  final String selection;
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
    required this.selection,
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
      selection: json['selection'] as String,
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
        selection: selection,
        odds: odds,
        stake: stake,
        potentialPayout: potentialPayout,
        status: status,
        createdAt: createdAt,
        match: match?.toEntity(),
      );
}
