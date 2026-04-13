import 'package:equatable/equatable.dart';

class Odds extends Equatable {
  final String id;
  final String matchId;
  final double homeOdds;
  final double awayOdds;
  final double? drawOdds;
  final bool isActive;
  final DateTime updatedAt;

  const Odds({
    required this.id,
    required this.matchId,
    required this.homeOdds,
    required this.awayOdds,
    this.drawOdds,
    required this.isActive,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, matchId, homeOdds, awayOdds, drawOdds, isActive];
}

class OddsUpdateEvent extends Equatable {
  final String matchId;
  final double homeOdds;
  final double awayOdds;
  final double? drawOdds;

  const OddsUpdateEvent({
    required this.matchId,
    required this.homeOdds,
    required this.awayOdds,
    this.drawOdds,
  });

  @override
  List<Object?> get props => [matchId, homeOdds, awayOdds, drawOdds];
}
