import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../odds/presentation/providers/odds_provider.dart';
import '../../domain/entities/betting_entity.dart';
import '../providers/betting_provider.dart';

class MatchCard extends ConsumerWidget {
  final Match match;
  final BetCartItem? selectedItem;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final void Function(Match match, Market market, MarketSelection selection)
      onSelectionTap;

  const MatchCard({
    super.key,
    required this.match,
    required this.onSelectionTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.selectedItem,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUpdate = ref.watch(matchOddsStateProvider)[match.id];

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
                const SizedBox(width: 4),
                if (onFavoriteToggle != null)
                  IconButton(
                    tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                    onPressed: onFavoriteToggle,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      color: isFavorite
                          ? AppTheme.warningColor
                          : AppTheme.textMuted,
                    ),
                  ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            if (match.isUpcoming || match.isLive) ...[
              for (final market in match.markets) ...[
                Text(
                  market.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: market.selections.map((selection) {
                    final liveSelection = mergeLiveSelection(
                      market,
                      selection,
                      liveUpdate,
                    );
                    return _oddButton(
                      market: market,
                      selection: liveSelection,
                      priceUpdated: liveSelection.odds != selection.odds,
                      isSelected: selectedItem?.market.key == market.key &&
                          selectedItem?.selection.key == selection.key,
                      onTap: () => onSelectionTap(match, market, liveSelection),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],
            ],
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
        color: color.withValues(alpha: 0.15),
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

  Widget _oddButton({
    required Market market,
    required MarketSelection selection,
    required bool priceUpdated,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final borderColor =
        isSelected ? AppTheme.primaryColor : AppTheme.darkBorder;

    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : AppTheme.darkBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selection.label,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selection.odds.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.primaryColor,
                    ),
                    maxLines: 1,
                  ),
                  if (priceUpdated) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.sync,
                      size: 12,
                      color: AppTheme.warningColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                market.key.replaceAll('_', ' ').toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  color: AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
