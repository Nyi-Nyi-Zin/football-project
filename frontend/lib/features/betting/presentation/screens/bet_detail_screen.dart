import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/betting_entity.dart';
import '../providers/betting_provider.dart';

class BetDetailScreen extends ConsumerStatefulWidget {
  final String betId;

  const BetDetailScreen({super.key, required this.betId});

  @override
  ConsumerState<BetDetailScreen> createState() => _BetDetailScreenState();
}

class _BetDetailScreenState extends ConsumerState<BetDetailScreen> {
  bool _isCashOutLoading = false;
  bool _isCancelLoading = false;

  @override
  Widget build(BuildContext context) {
    final betState = ref.watch(betDetailProvider(widget.betId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bet Details')),
      body: betState.when(
        data: _buildContent,
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => _errorState(error),
      ),
    );
  }

  Widget _buildContent(Bet bet) {
    final statusColor = _statusColor(bet.status);
    final matchTitle = bet.match == null
        ? 'Match ${bet.matchId.length > 8 ? bet.matchId.substring(0, 8) : bet.matchId}'
        : '${bet.match!.homeTeam} vs ${bet.match!.awayTeam}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(_statusIcon(bet.status), color: statusColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  _statusLabel(bet.status),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  matchTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (bet.match?.status == 'finished') ...[
                  const SizedBox(height: 6),
                  Text(
                    'Match finished — settlement is reflected below.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detailRow('Selection', bet.selectionLabel),
                _detailRow('Market', bet.marketKey),
                _detailRow('Type', bet.betType),
                _detailRow('Odds', bet.odds.toStringAsFixed(2)),
                _detailRow('Stake', '${bet.stake.toStringAsFixed(2)} MMK'),
                _detailRow(
                  'Potential payout',
                  '${bet.potentialPayout.toStringAsFixed(2)} MMK',
                  valueColor: AppTheme.accentColor,
                ),
                _detailRow(
                  'Placed at',
                  DateFormat('yyyy-MM-dd HH:mm')
                      .format(bet.createdAt.toLocal()),
                ),
                _detailRow('Bet ID', bet.id),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (bet.status.toLowerCase() == 'active') ...[
          ElevatedButton.icon(
            onPressed: _isCashOutLoading
                ? null
                : () => _showCashOutQuote(context, bet.id),
            icon: _isCashOutLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_clock_outlined),
            label: Text(_isCashOutLoading
                ? 'Processing cash-out...'
                : 'Get cash-out quote'),
          ),
          const SizedBox(height: 10),
        ],
        if (bet.isPending)
          OutlinedButton(
            onPressed: _isCancelLoading ? null : () => _cancelBet(bet.id),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isCancelLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel bet'),
          ),
      ],
    );
  }

  Future<void> _cancelBet(String betId) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCancelLoading = true);
    final cancelled = await ref.read(myBetsProvider.notifier).cancelBet(betId);
    if (!mounted) return;
    setState(() => _isCancelLoading = false);
    if (cancelled) {
      ref.invalidate(betDetailProvider(widget.betId));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bet cancelled and stake refunded.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bet could not be cancelled. Please try again.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _showCashOutQuote(BuildContext context, String betId) async {
    final dialogHost = context;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isCashOutLoading = true);
    try {
      final quote =
          await ref.read(bettingDataSourceProvider).getCashOutQuote(betId);
      if (!mounted) return;

      final amount = (quote['quoted_amount'] as num?)?.toDouble() ?? 0;
      final currentOdds = (quote['current_odds'] as num?)?.toDouble() ?? 0;
      final expiresAt =
          DateTime.tryParse(quote['expires_at'] as String? ?? '')?.toUtc();
      if (amount <= 0 || expiresAt == null) {
        throw StateError(
            'Cash-out quote is incomplete. Please request a new quote.');
      }

      // The mounted guard above protects this dialog host after the quote await.
      // ignore: use_build_context_synchronously
      final accepted = await showDialog<bool>(
        context: dialogHost,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cash-out quote'),
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
              Text('Valid until: ${expiresAt.toLocal()}'),
              const SizedBox(height: 12),
              const Text(
                'The quote is revalidated against live odds before your wallet is credited. If it expires or changes, request a new quote.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Accept & cash-out'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;

      if (!expiresAt.isAfter(DateTime.now().toUtc())) {
        throw StateError(
            'Cash-out quote has expired. Please request a new quote.');
      }

      await ref.read(bettingDataSourceProvider).executeCashOut(betId);
      ref.invalidate(betDetailProvider(widget.betId));
      ref.invalidate(myBetsProvider);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Cash-out completed: ${amount.toStringAsFixed(2)} MMK credited.',
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_friendlyCashOutError(error)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCashOutLoading = false);
    }
  }

  Widget _errorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppTheme.warningColor),
            const SizedBox(height: 12),
            const Text(
              'Unable to load bet details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyCashOutError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(betDetailProvider(widget.betId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyCashOutError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map<String, dynamic>) {
        final errorData = responseData['error'];
        if (errorData is Map<String, dynamic> &&
            errorData['message'] is String) {
          return errorData['message'] as String;
        }
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Please check your internet connection and try again.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The request took too long. Please try again.';
      }
    }
    if (error is StateError) return error.message;
    return 'Cash-out is temporarily unavailable. Please request a new quote and try again.';
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    if (status == 'settled') return 'CASHED OUT';
    return status.toUpperCase();
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'won':
        return Icons.check_circle;
      case 'lost':
        return Icons.cancel;
      case 'settled':
        return Icons.account_balance_wallet;
      case 'cancelled':
        return Icons.undo;
      default:
        return Icons.schedule;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'won':
        return AppTheme.successColor;
      case 'lost':
        return AppTheme.errorColor;
      case 'settled':
        return AppTheme.primaryColor;
      case 'cancelled':
        return AppTheme.textSecondary;
      default:
        return AppTheme.warningColor;
    }
  }
}
