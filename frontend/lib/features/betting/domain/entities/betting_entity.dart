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
  });

  bool get isLive => status == 'live';
  bool get isUpcoming => status == 'upcoming';
  bool get isFinished => status == 'finished';

  @override
  List<Object?> get props => [id];
}

class Bet extends Equatable {
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
  final Match? match;

  const Bet({
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

  bool get isPending => status == 'pending' || status == 'active';
  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
  bool get isCancelled => status == 'cancelled';

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
