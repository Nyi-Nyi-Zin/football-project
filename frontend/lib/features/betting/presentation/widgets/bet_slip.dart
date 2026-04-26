import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/betting_provider.dart';

class BetSlip extends ConsumerStatefulWidget {
  const BetSlip({super.key});

  @override
  ConsumerState<BetSlip> createState() => _BetSlipState();
}

class _BetSlipState extends ConsumerState<BetSlip> {
  final _stakeController = TextEditingController();
  bool _isPlacing = false;

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  Future<void> _placeBet() async {
    final stake = double.tryParse(_stakeController.text);
    final items = ref.read(betCartProvider);
    if (stake == null || stake <= 0 || items.isEmpty) return;

    setState(() => _isPlacing = true);

    final success = await ref.read(betCartProvider.notifier).placeSelections(stake);

    setState(() => _isPlacing = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (items.length == 1
                    ? 'Bet placed successfully!'
                    : 'Accumulator placed successfully!')
                : 'Failed to place bet',
          ),
          backgroundColor:
              success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(betCartProvider);
    final combinedOdds = items.isEmpty
        ? 0.0
        : items.fold<double>(1, (value, item) => value * item.selection.odds);
    final stake = double.tryParse(_stakeController.text) ?? 0;
    final potentialPayout = stake * combinedOdds;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Accumulator Slip',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              items.isEmpty
                  ? 'Add a selection to place a bet'
                  : items.length == 1
                      ? 'Single bet ready'
                      : '${items.length} selections added',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No selections yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.match.homeTeam} vs ${item.match.awayTeam}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.match.league} • ${item.market.name} • ${item.selection.label}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            item.selection.odds.toStringAsFixed(2),
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => ref
                                .read(betCartProvider.notifier)
                                .removeMatch(item.match.id),
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Combined Odds',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                Text(
                  combinedOdds.toStringAsFixed(2),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stakeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stake Amount',
                suffixText: ' MMK',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [500, 1000, 2000, 5000, 10000].map((amount) {
                return OutlinedButton(
                  onPressed: () {
                    _stakeController.text = amount.toString();
                    setState(() {});
                  },
                  child: Text('$amount MMK'),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Potential Payout',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                Text(
                  '${potentialPayout.toStringAsFixed(2)} MMK',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentColor,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isPlacing || items.isEmpty ? null : _placeBet,
                child: _isPlacing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        items.length == 1
                            ? 'Place Bet'
                            : 'Place Accumulator',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
