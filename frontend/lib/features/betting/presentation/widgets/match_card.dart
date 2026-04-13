import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/betting_entity.dart';

class MatchCard extends StatelessWidget {
  final Match match;
  final Function(String selection) onPlaceBet;

  const MatchCard({
    super.key,
    required this.match,
    required this.onPlaceBet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // League + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    match.league,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(),
              ],
            ),
            const SizedBox(height: 12),

            // Teams
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.homeTeam,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (match.isLive || match.isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${match.homeScore ?? 0} - ${match.awayScore ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                else
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                Expanded(
                  child: Text(
                    match.awayTeam,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Betting buttons
            if (match.isUpcoming || match.isLive)
              Row(
                children: [
                  _oddButton('Home', '1.85', () => onPlaceBet('home')),
                  const SizedBox(width: 8),
                  _oddButton('Draw', '3.40', () => onPlaceBet('draw')),
                  const SizedBox(width: 8),
                  _oddButton('Away', '2.10', () => onPlaceBet('away')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge() {
    Color color;
    String label;

    if (match.isLive) {
      color = AppTheme.errorColor;
      label = '● LIVE';
    } else if (match.isUpcoming) {
      color = AppTheme.primaryColor;
      label = 'UPCOMING';
    } else {
      color = AppTheme.textMuted;
      label = 'FINISHED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _oddButton(String label, String odds, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.darkBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  odds,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.primaryColor,
                  ),
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
