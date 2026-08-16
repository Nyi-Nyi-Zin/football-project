import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/betting_provider.dart';

class BetDetailScreen extends ConsumerWidget {
  final String betId;

  const BetDetailScreen({super.key, required this.betId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final betsState = ref.watch(myBetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bet Details')),
      body: betsState.when(
        data: (bets) {
          final bet = bets.where((b) => b.id == betId).firstOrNull;
          if (bet == null) {
            return const Center(child: Text('Bet not found'));
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          bet.isWon
                              ? Icons.check_circle
                              : bet.isLost
                                  ? Icons.cancel
                                  : Icons.schedule,
                          color: bet.isWon
                              ? AppTheme.successColor
                              : bet.isLost
                                  ? AppTheme.errorColor
                                  : AppTheme.warningColor,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bet.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: bet.isWon
                                ? AppTheme.successColor
                                : bet.isLost
                                    ? AppTheme.errorColor
                                    : AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Details
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _detailRow('Selection', bet.selection.toUpperCase()),
                        _detailRow('Type', bet.betType),
                        _detailRow('Odds', bet.odds.toStringAsFixed(2)),
                        _detailRow(
                            'Stake', '${bet.stake.toStringAsFixed(2)} MMK'),
                        _detailRow(
                          'Potential Payout',
                          '${bet.potentialPayout.toStringAsFixed(2)} MMK',
                          valueColor: AppTheme.accentColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                if (bet.status.toLowerCase() == 'active') ...[
                  ElevatedButton.icon(
                    onPressed: () => _showCashOutQuote(context, ref, bet.id),
                    icon: const Icon(Icons.lock_clock_outlined),
                    label: const Text('Get Cash-out Quote'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (bet.isPending)
                  OutlinedButton(
                    onPressed: () async {
                      final cancelled = await ref
                          .read(myBetsProvider.notifier)
                          .cancelBet(betId);
                      if (context.mounted && cancelled) {
                        Navigator.pop(context);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Cancel Bet'),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading bet')),
      ),
    );
  }

  Future<void> _showCashOutQuote(
    BuildContext context,
    WidgetRef ref,
    String betId,
  ) async {
    try {
      final dataSource = ref.read(bettingDataSourceProvider);
      final quote = await dataSource.getCashOutQuote(betId);
      if (!context.mounted) return;
      final amount = (quote['quoted_amount'] as num?)?.toDouble() ?? 0;
      final currentOdds = (quote['current_odds'] as num?)?.toDouble() ?? 0;
      final expiresAt = DateTime.tryParse(quote['expires_at'] as String? ?? '');
      final accepted = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cash-out Quote'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${amount.toStringAsFixed(2)} MMK',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text('Current odds: ${currentOdds.toStringAsFixed(2)}'),
              if (expiresAt != null)
                Text('Valid until: ${expiresAt.toLocal()}'),
              const SizedBox(height: 12),
              const Text(
                'The quote will be revalidated against live odds before your wallet is credited.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept & Cash-out'),
            ),
          ],
        ),
      );
      if (accepted != true || !context.mounted) return;

      await dataSource.executeCashOut(betId);
      await ref.read(myBetsProvider.notifier).loadBets();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cash-out completed: ${amount.toStringAsFixed(2)} MMK credited'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cash-out failed: $error'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
