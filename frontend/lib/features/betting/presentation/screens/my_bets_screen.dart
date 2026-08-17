import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/betting_provider.dart';
import '../../domain/entities/betting_entity.dart';

class MyBetsScreen extends ConsumerStatefulWidget {
  const MyBetsScreen({super.key});

  @override
  ConsumerState<MyBetsScreen> createState() => _MyBetsScreenState();
}

class _MyBetsScreenState extends ConsumerState<MyBetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('myBets')),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Single Bets'),
            Tab(text: 'Accumulators'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSingleBets(),
          _buildAccumulators(),
        ],
      ),
    );
  }

  Widget _buildSingleBets() {
    final betsState = ref.watch(myBetsProvider);
    return betsState.when(
      data: (bets) {
        if (bets.isEmpty) {
          return Center(
            child: Text(
              context.l10n.tr('noBets'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(myBetsProvider.notifier).loadBets();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bets.length,
            itemBuilder: (context, index) {
              final bet = bets[index];
              return _betCard(bet);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorState(
        title: 'Unable to load your bets',
        error: e,
        onRetry: () => ref.invalidate(myBetsProvider),
      ),
    );
  }

  Widget _buildAccumulators() {
    final slipsState = ref.watch(myBetSlipsProvider);
    return slipsState.when(
      data: (slips) {
        if (slips.isEmpty) {
          return Center(
            child: Text(
              context.l10n.tr('noBets'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            await ref.refresh(myBetSlipsProvider.future).then<void>((_) {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: slips.length,
            itemBuilder: (context, index) {
              final slip = slips[index];
              return _slipCard(slip);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorState(
        title: 'Accumulators are temporarily unavailable',
        error: e,
        onRetry: () => ref.invalidate(myBetSlipsProvider),
      ),
    );
  }

  Widget _errorState({
    required String title,
    required Object error,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _friendlyError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null && status >= 500) {
        return 'The server is temporarily unavailable. Please try again in a moment.';
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
    return 'We could not load this page right now. Please try again.';
  }

  Widget _betCard(Bet bet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/bet/${bet.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bet.match?.homeTeam != null
                          ? '${bet.match!.homeTeam} vs ${bet.match!.awayTeam}'
                          : 'Match ${bet.matchId.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(bet.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(bet.createdAt)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Selection: ${bet.selectionLabel} (${bet.odds.toStringAsFixed(2)})',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Stake: ${bet.stake.toStringAsFixed(2)} MMK'),
                  Text(
                    'Payout: ${bet.potentialPayout.toStringAsFixed(2)} MMK',
                    style: const TextStyle(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slipCard(BetSlip slip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Accumulator (${slip.legs.length} legs)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _statusBadge(slip.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(slip.createdAt)}',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...slip.legs.map((leg) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.circle,
                          size: 6, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${leg.match?.homeTeam ?? 'Match'} - ${leg.selectionLabel} (${leg.odds.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stake: ${slip.stake.toStringAsFixed(2)} MMK'),
                Text(
                  'Payout: ${slip.potentialPayout.toStringAsFixed(2)} MMK',
                  style: const TextStyle(
                      color: AppTheme.accentColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final bool isWon = status == 'won';
    final bool isLost = status == 'lost';
    final bool isCashedOut = status == 'settled';
    final Color color = isWon
        ? AppTheme.successColor
        : isLost
            ? AppTheme.errorColor
            : isCashedOut
                ? AppTheme.primaryColor
                : AppTheme.warningColor;
    final label = isCashedOut ? 'CASHED OUT' : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
