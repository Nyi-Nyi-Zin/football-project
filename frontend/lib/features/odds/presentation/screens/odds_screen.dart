import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/odds_provider.dart';
import '../../domain/entities/odds_entity.dart';

class OddsScreen extends ConsumerWidget {
  const OddsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to trigger WebSocket connection
    final wsStream = ref.watch(liveOddsProvider);
    final oddsMap = ref.watch(matchOddsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flash_on, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text(
              'Live Odds Flux',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: wsStream.isLoading
                ? AppTheme.warningColor.withValues(alpha: 0.1)
                : AppTheme.successColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: wsStream.isLoading ? AppTheme.warningColor : AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  wsStream.isLoading ? 'Connecting to live feed...' : 'Live Feed Active',
                  style: TextStyle(
                    color: wsStream.isLoading ? AppTheme.warningColor : AppTheme.successColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Live Odds List
          Expanded(
            child: oddsMap.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for odds updates...',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: oddsMap.length,
                    itemBuilder: (context, index) {
                      final matchId = oddsMap.keys.elementAt(index);
                      final odds = oddsMap[matchId]!;
                      
                      return _LiveOddsCard(odds: odds);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LiveOddsCard extends StatelessWidget {
  final OddsUpdateEvent odds;

  const _LiveOddsCard({required this.odds});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_soccer, color: AppTheme.primaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Match ID: ${odds.matchId.substring(0, 8)}...',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.live_tv, color: AppTheme.errorColor, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOddBox('HOME', odds.homeOdds),
                if (odds.drawOdds != null) _buildOddBox('DRAW', odds.drawOdds!),
                _buildOddBox('AWAY', odds.awayOdds),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOddBox(String label, double oddValue) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.darkBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            oddValue.toStringAsFixed(2),
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        )
      ],
    );
  }
}
