import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/betting_entity.dart';
import '../providers/betting_provider.dart';

class BetSlip extends ConsumerStatefulWidget {
  final Match match;
  final String selection;

  const BetSlip({super.key, required this.match, required this.selection});

  @override
  ConsumerState<BetSlip> createState() => _BetSlipState();
}

class _BetSlipState extends ConsumerState<BetSlip> {
  final _stakeController = TextEditingController();
  bool _isPlacing = false;
  final double _odds = 1.85; // Would come from odds module

  double get _potentialPayout {
    final stake = double.tryParse(_stakeController.text) ?? 0;
    return stake * _odds;
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  Future<void> _placeBet() async {
    final stake = double.tryParse(_stakeController.text);
    if (stake == null || stake <= 0) return;

    setState(() => _isPlacing = true);

    final bet = await ref.read(myBetsProvider.notifier).placeBet(
          matchId: widget.match.id,
          selection: widget.selection,
          stake: stake,
        );

    setState(() => _isPlacing = false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bet != null ? 'Bet placed successfully!' : 'Failed to place bet',
          ),
          backgroundColor: bet != null ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Handle bar
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
            'Place Bet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Match info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.match.homeTeam} vs ${widget.match.awayTeam}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.match.league} • Selection: ${widget.selection.toUpperCase()}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Odds display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Odds', style: TextStyle(color: AppTheme.textSecondary)),
              Text(
                _odds.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stake input
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

          // Quick stake buttons
          Row(
            children: [500, 1000, 2000, 5000, 10000].map((amount) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: OutlinedButton(
                    onPressed: () {
                      _stakeController.text = amount.toString();
                      setState(() {});
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '$amount MMK',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Potential payout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Potential Payout',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              Text(
                '${_potentialPayout.toStringAsFixed(2)} MMK',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentColor,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Place bet button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isPlacing ? null : _placeBet,
              child: _isPlacing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Place Bet'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
