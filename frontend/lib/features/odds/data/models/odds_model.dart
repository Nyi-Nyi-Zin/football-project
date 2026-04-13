import '../../domain/entities/odds_entity.dart';

class OddsModel {
  final String id;
  final String matchId;
  final double homeOdds;
  final double awayOdds;
  final double? drawOdds;
  final bool isActive;
  final DateTime updatedAt;

  const OddsModel({
    required this.id,
    required this.matchId,
    required this.homeOdds,
    required this.awayOdds,
    this.drawOdds,
    required this.isActive,
    required this.updatedAt,
  });

  factory OddsModel.fromJson(Map<String, dynamic> json) {
    return OddsModel(
      id: json['id'] as String,
      matchId: json['match_id'] as String,
      homeOdds: (json['home_odds'] as num).toDouble(),
      awayOdds: (json['away_odds'] as num).toDouble(),
      drawOdds: json['draw_odds'] != null ? (json['draw_odds'] as num).toDouble() : null,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Odds toEntity() {
    return Odds(
      id: id,
      matchId: matchId,
      homeOdds: homeOdds,
      awayOdds: awayOdds,
      drawOdds: drawOdds,
      isActive: isActive,
      updatedAt: updatedAt,
    );
  }
}
