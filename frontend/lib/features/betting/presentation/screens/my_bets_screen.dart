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

class _MyBetsScreenState extends ConsumerState<MyBetsScreen> with SingleTickerProviderStateMixin {
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
      error: (e, _) => Center(child: Text('Error: $e')),
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
            ref.invalidate(myBetSlipsProvider);
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
      error: (e, _) => Center(child: Text('Error: $e')),
    );
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
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                        color: AppTheme.accentColor, fontWeight: FontWeight.bold),
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
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...slip.legs.map((leg) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: AppTheme.primaryColor),
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
    final Color color = isWon
        ? AppTheme.successColor
        : isLost
            ? AppTheme.errorColor
            : AppTheme.warningColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
