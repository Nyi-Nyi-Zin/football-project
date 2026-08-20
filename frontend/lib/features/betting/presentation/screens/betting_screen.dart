import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/betting_entity.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../providers/betting_provider.dart';
import '../widgets/bet_slip.dart' as slip_widget;
import '../widgets/match_card.dart';

class BettingScreen extends ConsumerWidget {
  const BettingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(matchAutoRefreshProvider);
    final matchesState = ref.watch(matchesProvider);
    final selectedLeagues = ref.watch(selectedLeaguesProvider);
    final selectedStatus = ref.watch(selectedMatchStatusProvider);
    final searchQuery = ref.watch(matchSearchQueryProvider);
    final favoriteMatchIds = ref.watch(favoriteMatchIdsProvider);
    final unreadNotifications =
        ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final cartItems = ref.watch(betCartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Matches',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge.count(
              count: unreadNotifications,
              isLabelVisible: unreadNotifications > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(matchesRefreshKeyProvider.notifier).state++;
              ref.invalidate(myBetSlipsProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Live odds',
            onPressed: () => context.push('/live-odds'),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: () => _openBetSlip(context),
            icon: Badge.count(
              count: cartItems.length,
              isLabelVisible: cartItems.isNotEmpty,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
        ],
      ),
      body: matchesState.when(
        data: (matches) => _MatchesList(
          matches: matches,
          cartItems: cartItems,
          selectedStatus: selectedStatus,
          selectedLeagues: selectedLeagues,
          searchQuery: searchQuery,
          favoriteMatchIds: favoriteMatchIds,
          onSearchChanged: (value) =>
              ref.read(matchSearchQueryProvider.notifier).state = value,
          onFavoriteToggle: (matchId) =>
              ref.read(favoriteMatchIdsProvider.notifier).toggle(matchId),
          onStatusChanged: (status) {
            ref.read(selectedMatchStatusProvider.notifier).state = status;
            ref.read(matchesRefreshKeyProvider.notifier).state++;
          },
          onClearFilters: selectedLeagues.isEmpty
              ? null
              : () =>
                  ref.read(selectedLeaguesProvider.notifier).state = const [],
          onLeagueTap: (league, isSelected) {
            final next = [...selectedLeagues];
            if (isSelected) {
              next.remove(league);
            } else {
              next.add(league);
            }
            ref.read(selectedLeaguesProvider.notifier).state = next;
          },
          onRefresh: () async {
            ref.read(matchesRefreshKeyProvider.notifier).state++;
            ref.invalidate(matchesProvider);
            await ref.read(matchesProvider.future);
          },
          onSelectionTap: (match, market, selection) {
            ref.read(betCartProvider.notifier).toggleItem(
                  match: match,
                  market: market,
                  selection: selection,
                );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(matchesRefreshKeyProvider.notifier).state++,
        ),
      ),
      floatingActionButton: cartItems.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openBetSlip(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.receipt_long),
              label: Text(
                cartItems.length >= 2
                    ? 'Slip (${cartItems.length})'
                    : 'Add More (${cartItems.length})',
              ),
            ),
    );
  }

  void _openBetSlip(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const slip_widget.BetSlip(),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final List<String> selectedLeagues;
  final int selectionCount;
  final double combinedOdds;
  final VoidCallback? onClearFilters;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _HeaderSummary({
    required this.selectedLeagues,
    required this.selectionCount,
    required this.combinedOdds,
    required this.onClearFilters,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.72),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146446A0),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: TextEditingController(text: searchQuery)
              ..selection = TextSelection.collapsed(offset: searchQuery.length),
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search teams or leagues',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => onSearchChanged(''),
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.88),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '1xBet-style Markets',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedLeagues.isEmpty
                ? 'Showing all tracked leagues with generic market options.'
                : 'Filtering ${selectedLeagues.length} league(s) with market-based selections.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'Leagues',
                  value: selectedLeagues.isEmpty
                      ? 'All 6'
                      : selectedLeagues.length.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: 'Selections',
                  value: selectionCount.toString(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryPill(
                  label: 'Combined',
                  value: selectionCount == 0
                      ? '--'
                      : combinedOdds.toStringAsFixed(2),
                ),
              ),
            ],
          ),
          if (onClearFilters != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear league filters'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryPill({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  final List<Match> matches;
  final List<BetCartItem> cartItems;
  final String? selectedStatus;
  final List<String> selectedLeagues;
  final String searchQuery;
  final Set<String> favoriteMatchIds;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFavoriteToggle;
  final void Function(String? status) onStatusChanged;
  final VoidCallback? onClearFilters;
  final void Function(String league, bool isSelected) onLeagueTap;
  final RefreshCallback onRefresh;
  final void Function(Match match, Market market, MarketSelection selection)
      onSelectionTap;

  const _MatchesList({
    required this.matches,
    required this.cartItems,
    required this.selectedStatus,
    required this.selectedLeagues,
    required this.searchQuery,
    required this.favoriteMatchIds,
    required this.onSearchChanged,
    required this.onFavoriteToggle,
    required this.onStatusChanged,
    required this.onClearFilters,
    required this.onLeagueTap,
    required this.onRefresh,
    required this.onSelectionTap,
  });

  // Number of extra header items before the match cards
  static const int _headerCount = 3; // summary + status chips + league chips

  @override
  Widget build(BuildContext context) {
    final selectionCount = cartItems.length;
    final combinedOdds = cartItems.isEmpty
        ? 0.0
        : cartItems.fold<double>(1, (v, item) => v * item.selection.odds);
    final query = searchQuery.trim().toLowerCase();
    final visibleMatches = matches.where((match) {
      if (query.isEmpty) return true;
      return match.homeTeam.toLowerCase().contains(query) ||
          match.awayTeam.toLowerCase().contains(query) ||
          match.league.toLowerCase().contains(query);
    }).toList();

    if (visibleMatches.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _HeaderSummary(
              selectedLeagues: selectedLeagues,
              searchQuery: searchQuery,
              onSearchChanged: onSearchChanged,
              selectionCount: selectionCount,
              combinedOdds: combinedOdds,
              onClearFilters: onClearFilters,
            ),
            _MatchStatusRow(
              selectedStatus: selectedStatus,
              onStatusChanged: onStatusChanged,
            ),
            _LeagueFilterRow(
              selectedLeagues: selectedLeagues,
              onLeagueTap: onLeagueTap,
            ),
            const SizedBox(height: 120),
            const Icon(
              Icons.sports_soccer_outlined,
              size: 72,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'No matches found for the selected filters.'
                  : 'No matches found for “$searchQuery”.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        itemCount: visibleMatches.length + _headerCount,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _HeaderSummary(
              selectedLeagues: selectedLeagues,
              searchQuery: searchQuery,
              onSearchChanged: onSearchChanged,
              selectionCount: selectionCount,
              combinedOdds: combinedOdds,
              onClearFilters: onClearFilters,
            );
          }
          if (index == 1) {
            return _MatchStatusRow(
              selectedStatus: selectedStatus,
              onStatusChanged: onStatusChanged,
            );
          }
          if (index == 2) {
            return _LeagueFilterRow(
              selectedLeagues: selectedLeagues,
              onLeagueTap: onLeagueTap,
            );
          }
          final match = visibleMatches[index - _headerCount];
          final selectedItem =
              cartItems.where((item) => item.match.id == match.id).firstOrNull;
          return MatchCard(
            match: match,
            selectedItem: selectedItem,
            isFavorite: favoriteMatchIds.contains(match.id),
            onFavoriteToggle: () => onFavoriteToggle(match.id),
            onSelectionTap: onSelectionTap,
          );
        },
      ),
    );
  }
}

class _MatchStatusRow extends StatelessWidget {
  final String? selectedStatus;
  final void Function(String? status) onStatusChanged;

  const _MatchStatusRow({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = <(String?, String)>[
      (null, 'All'),
      ('upcoming', 'Upcoming'),
      ('live', 'Live'),
    ];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (status, label) = filters[index];
          return ChoiceChip(
            label: Text(label),
            selected: selectedStatus == status,
            avatar: status == 'live'
                ? const Icon(Icons.circle, size: 10, color: AppTheme.errorColor)
                : null,
            onSelected: (_) => onStatusChanged(status),
          );
        },
      ),
    );
  }
}

class _LeagueFilterRow extends StatelessWidget {
  final List<String> selectedLeagues;
  final void Function(String league, bool isSelected) onLeagueTap;

  const _LeagueFilterRow({
    required this.selectedLeagues,
    required this.onLeagueTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 0),
        scrollDirection: Axis.horizontal,
        itemCount: availableLeagueFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final league = availableLeagueFilters[index];
          final isSelected = selectedLeagues.contains(league);
          return FilterChip(
            label: Text(league),
            selected: isSelected,
            onSelected: (_) => onLeagueTap(league, isSelected),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load matches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
