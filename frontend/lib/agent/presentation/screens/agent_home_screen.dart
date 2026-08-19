import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../core/agent_error_message.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/payment/domain/entities/payment_entity.dart';
import '../../../features/payment/presentation/providers/payment_provider.dart';
import '../../../features/notification/domain/entities/notification_entity.dart';
import '../../../features/notification/presentation/providers/notification_provider.dart';
import '../../data/agent_models.dart';
import '../providers/agent_provider.dart';

String _normalizeCustomerUserId(String raw) {
  final trimmed = raw.trim();
  final match = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  ).firstMatch(trimmed);
  return (match?.group(0) ?? trimmed).toLowerCase();
}

String _customerDepositErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final apiError = data['error'];
      if (apiError is Map) {
        final message = apiError['message'];
        final details = apiError['details'];
        if (message is String && details is String && details.isNotEmpty) {
          return '$message: $details';
        }
        if (message is String && message.isNotEmpty) return message;
      }
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        return data['message'] as String;
      }
    }
    if (error.error is ServerException) {
      return (error.error as ServerException).message;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }
    if (error.response?.statusCode == 400) {
      return 'Deposit request was rejected. Check the customer User ID and available Agent balance.';
    }
  }
  return 'Unable to complete customer deposit. Please try again.';
}

class AgentHomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const AgentHomeScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends ConsumerState<AgentHomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Agent Wallet',
      'Alerts',
      'Profile',
    ];
    final pages = <Widget>[
      const _AgentWalletTab(),
      const _AgentNotificationsTab(),
      const _AgentProfileTab(),
    ];
    final connectivity = ref.watch(agentConnectivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          _AgentConnectivityBadge(state: connectivity),
          if (!connectivity.isOnline && !connectivity.isChecking)
            IconButton(
              onPressed: _resync,
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Resync app',
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  void _resync() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(notificationProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.read(agentConnectivityProvider.notifier).checkNow();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resync started. Checking connection…')),
    );
  }
}

class _AgentConnectivityBadge extends StatelessWidget {
  final AgentConnectivityState state;

  const _AgentConnectivityBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state.isChecking
        ? Colors.orange
        : state.isOnline
            ? AppTheme.successColor
            : AppTheme.errorColor;
    final label = state.isChecking
        ? 'Checking'
        : state.isOnline
            ? 'Online'
            : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isChecking)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AgentDashboardTab extends ConsumerWidget {
  const _AgentDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(agentDashboardProvider);
    final transactionsState = ref.watch(transactionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(agentDashboardProvider);
        ref.invalidate(transactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _AgentDashboardHero(summaryState: dashboardState),
          const SizedBox(height: 16),
          dashboardState.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(agentFriendlyError(error,
                    fallback: 'Dashboard metrics are unavailable.')),
              ),
            ),
            data: (summary) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AgentMetricCard(
                        icon: Icons.pending_actions,
                        label: 'Pending payouts',
                        value: summary.pendingPayouts.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AgentMetricCard(
                        icon: Icons.receipt_long,
                        label: 'Recent entries',
                        value: summary.recentTransactions.toString(),
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AgentMetricCard(
                        icon: Icons.arrow_downward,
                        label: 'Today deposits',
                        value:
                            '${summary.todayDeposits.toStringAsFixed(0)} ${summary.currency}',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AgentMetricCard(
                        icon: Icons.arrow_upward,
                        label: 'Today payouts',
                        value:
                            '${summary.todayPayouts.toStringAsFixed(0)} ${summary.currency}',
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _AgentEarningsCard(),
          const SizedBox(height: 12),
          const _AgentCommissionCard(),
          const SizedBox(height: 12),
          const _AgentReconciliationCard(),
          const SizedBox(height: 20),
          Text(
            'Quick operations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Use Wallet to credit an assigned customer or review your agent ledger.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/wallet'),
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Open Agent Wallet'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/withdrawals'),
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Open Payout Queue'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          transactionsState.when(
            loading: () => const _AgentSkeletonList(rows: 3),
            error: (error, _) => Text(agentFriendlyError(error,
                fallback: 'Recent activity is unavailable.')),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No activity yet.')),
                    ),
                  )
                : Column(
                    children: items
                        .take(3)
                        .map((transaction) => _TransactionTile(
                              transaction: transaction,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AgentDashboardHero extends StatelessWidget {
  final AsyncValue<AgentDashboardSummary> summaryState;

  const _AgentDashboardHero({required this.summaryState});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff8050D0), Color(0xffA080E0)],
          ),
        ),
        child: summaryState.when(
          loading: () => const SizedBox(
            height: 116,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AgentSkeletonBlock(width: 150, height: 16),
                _AgentSkeletonBlock(width: 250, height: 28),
                _AgentSkeletonBlock(width: 230, height: 13),
              ],
            ),
          ),
          error: (_, __) => const ListTile(
            contentPadding: EdgeInsets.zero,
            textColor: Colors.white,
            iconColor: Colors.white,
            leading: Icon(Icons.cloud_off),
            title: Text('Wallet unavailable'),
            subtitle: Text('Open Wallet and retry the balance request.'),
          ),
          data: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cloud 9 Agent operations',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                '${summary.availableBalance.toStringAsFixed(2)} ${summary.currency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Available balance • reserved ${summary.reservedBalance.toStringAsFixed(2)} ${summary.currency}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentEarningsCard extends ConsumerWidget {
  const _AgentEarningsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentEarningsProvider);
    final selectedDays = ref.watch(agentEarningsDaysProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const _AgentSkeletonCard(height: 150),
          error: (error, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.analytics_outlined),
            title: const Text('Earnings summary unavailable'),
            subtitle: Text(agentFriendlyError(error)),
            trailing: IconButton(
              onPressed: () => ref.invalidate(agentEarningsProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          data: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Settlement summary',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  DropdownButton<int>(
                    value: selectedDays,
                    underline: const SizedBox.shrink(),
                    items: const [7, 30, 90]
                        .map((days) => DropdownMenuItem<int>(
                              value: days,
                              child: Text('$days days'),
                            ))
                        .toList(),
                    onChanged: (days) {
                      if (days != null) {
                        ref.read(agentEarningsDaysProvider.notifier).state =
                            days;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Settled ledger activity; commission rules are not applied yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AgentEarningsMetric(
                      label: 'Customer deposits',
                      value:
                          '${summary.depositAmount.toStringAsFixed(0)} ${summary.currency}',
                      count: summary.depositCount,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AgentEarningsMetric(
                      label: 'Payouts received',
                      value:
                          '${summary.payoutAmount.toStringAsFixed(0)} ${summary.currency}',
                      count: summary.payoutCount,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Net settlement: ${summary.netSettlement.toStringAsFixed(0)} ${summary.currency}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${summary.pendingPayoutCount} pending'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentEarningsMetric extends StatelessWidget {
  final String label;
  final String value;
  final int count;
  final Color color;

  const _AgentEarningsMetric({
    required this.label,
    required this.value,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text('$count transactions',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _AgentMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AgentMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AgentCustomersTab extends ConsumerStatefulWidget {
  const _AgentCustomersTab();

  @override
  ConsumerState<_AgentCustomersTab> createState() => _AgentCustomersTabState();
}

class _AgentCustomersTabState extends ConsumerState<_AgentCustomersTab> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(agentCustomerQueryProvider.notifier).state =
        _queryController.text.trim();
    ref.invalidate(agentCustomersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(agentCustomersProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(agentCustomersProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'Customer operations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Only customers connected to your assigned deposits or payouts are shown.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Search ID, name, email, phone, or username',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.arrow_forward),
                tooltip: 'Search',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          customersState.when(
            loading: () => const _AgentSkeletonList(rows: 3),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 40),
                    const SizedBox(height: 8),
                    Text(agentFriendlyError(error,
                        fallback: 'Customer data is unavailable.')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(agentCustomersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (customers) => customers.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No connected customers found.'),
                      ),
                    ),
                  )
                : Column(
                    children: customers
                        .map(
                          (customer) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AgentCustomerCard(
                              customer: customer,
                              onTap: () => _showCustomerDetails(customer),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerDetails(AgentCustomerSummary customer) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<AgentCustomerActivity>(
        future:
            ref.read(agentDataSourceProvider).getCustomerActivity(customer.id),
        builder: (context, activitySnapshot) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName.isEmpty
                      ? customer.username
                      : customer.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text('${customer.email} • ${customer.status}'),
                const Divider(height: 24),
                _CustomerDetailRow(label: 'Customer ID', value: customer.id),
                _CustomerDetailRow(label: 'Username', value: customer.username),
                _CustomerDetailRow(label: 'Phone', value: customer.phone),
                _CustomerDetailRow(
                  label: 'Balance',
                  value: '${customer.balance.toStringAsFixed(2)} MMK',
                ),
                const SizedBox(height: 16),
                Text(
                  'Shared activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                if (activitySnapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (activitySnapshot.hasError)
                  Text('Activity unavailable: ${activitySnapshot.error}')
                else ...[
                  for (final transaction
                      in activitySnapshot.data?.transactions ??
                          const <Transaction>[])
                    _CustomerActivityRow(
                      title: transaction.displayType,
                      subtitle:
                          '${transaction.status} • ${transaction.createdAt.toLocal().toString().split('.').first}',
                      amount:
                          '${transaction.isCredit ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                    ),
                  for (final withdrawal in activitySnapshot.data?.withdrawals ??
                      const <AgentWithdrawalItem>[])
                    _CustomerActivityRow(
                      title: 'Withdrawal request',
                      subtitle:
                          '${withdrawal.requestStatus} • ${withdrawal.createdAt.toLocal().toString().split('.').first}',
                      amount:
                          '${withdrawal.amount.toStringAsFixed(2)} ${withdrawal.currency}',
                    ),
                  if ((activitySnapshot.data?.transactions.isEmpty ?? true) &&
                      (activitySnapshot.data?.withdrawals.isEmpty ?? true))
                    const Text('No shared activity recorded yet.'),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: customer.id));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Customer ID copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy ID'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/wallet'),
                        icon: const Icon(Icons.add_card),
                        label: const Text('Deposit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentCustomerCard extends StatelessWidget {
  final AgentCustomerSummary customer;
  final VoidCallback onTap;

  const _AgentCustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName =
        customer.fullName.isEmpty ? customer.username : customer.fullName;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(displayName.isEmpty ? '?' : displayName[0].toUpperCase()),
        ),
        title: Text(displayName),
        subtitle: Text('${customer.username} • ${customer.status}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CustomerDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _CustomerDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

class _AgentWalletTab extends ConsumerStatefulWidget {
  const _AgentWalletTab();

  @override
  ConsumerState<_AgentWalletTab> createState() => _AgentWalletTabState();
}

class _AgentWalletTabState extends ConsumerState<_AgentWalletTab> {
  _CustomerDepositReceipt? _lastCustomerDeposit;

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final transactionsState = ref.watch(transactionsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(walletProvider.notifier).fetchBalance();
        ref.invalidate(transactionsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          walletState.when(
            loading: () => const _AgentSkeletonCard(height: 220, rows: 4),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 8),
                    Text(agentFriendlyError(error,
                        fallback: 'Wallet data is unavailable.')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.read(walletProvider.notifier).fetchBalance(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (wallet) => _WalletBalanceCard(
              wallet: wallet,
              onDeposit: () => _openDepositDialog(context, ref),
              onWithdraw: () => _openWithdrawDialog(context, ref, wallet),
            ),
          ),
          if (_lastCustomerDeposit != null) ...[
            const SizedBox(height: 16),
            _CustomerDepositReceiptCard(receipt: _lastCustomerDeposit!),
          ],
          const SizedBox(height: 22),
          Text(
            'Agent wallet transactions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          transactionsState.when(
            loading: () => const _AgentSkeletonList(rows: 3),
            error: (error, _) => Text(agentFriendlyError(error,
                fallback: 'Transactions are unavailable.')),
            data: (transactions) => transactions.isEmpty
                ? const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No transactions yet.')),
                    ),
                  )
                : Column(
                    children: transactions
                        .take(10)
                        .map((transaction) => _TransactionTile(
                              transaction: transaction,
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDepositDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final customerIdCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var saving = false;
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Deposit to customer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter the customer User ID and the amount to credit.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: customerIdCtrl,
                    maxLength: 36,
                    decoration: const InputDecoration(
                      labelText: 'Customer User ID',
                      helperText:
                          'Paste the Customer app Profile User ID, not your Agent ID.',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      suffixText: 'MMK',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final customerId =
                            _normalizeCustomerUserId(customerIdCtrl.text);
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (!uuidPattern.hasMatch(customerId)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter the complete customer User ID UUID.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a valid MMK amount.'),
                            ),
                          );
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          await ref
                              .read(paymentDatasourceProvider)
                              .depositForCustomer(
                                customerId: customerId,
                                amount: amount,
                              );
                          if (!context.mounted) return;
                          await ref
                              .read(walletProvider.notifier)
                              .fetchBalance();
                          await ref
                              .refresh(transactionsProvider.future)
                              .then<void>((_) {});
                          if (!context.mounted) return;
                          setState(() {
                            _lastCustomerDeposit = _CustomerDepositReceipt(
                              customerId: customerId,
                              amount: amount,
                              completedAt: DateTime.now(),
                            );
                          });
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Customer deposit completed successfully.',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          setState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Customer deposit failed: ${_customerDepositErrorMessage(error)}',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Deposit'),
              ),
            ],
          ),
        ),
      );
    } finally {
      customerIdCtrl.dispose();
      amountCtrl.dispose();
    }
  }

  Future<void> _openWithdrawDialog(
    BuildContext context,
    WidgetRef ref,
    Wallet wallet,
  ) async {
    final codeCtrl = TextEditingController();
    var verifying = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Confirm customer payout'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter the withdrawal request code generated in the Customer app. When it is confirmed, the held customer funds will settle into your Agent wallet.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Agent wallet: ${wallet.availableBalance.toStringAsFixed(2)} MMK',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    enabled: !verifying,
                    decoration: const InputDecoration(
                      labelText: 'Withdrawal request code',
                      hintText: 'ABC123',
                      helperText: 'Use the code shown in the Customer app.',
                      counterText: '',
                      prefixIcon: Icon(Icons.password_outlined),
                    ),
                    onChanged: (value) {
                      final upper = value.toUpperCase();
                      if (upper != value) {
                        codeCtrl.value = codeCtrl.value.copyWith(
                          text: upper,
                          selection:
                              TextSelection.collapsed(offset: upper.length),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    verifying ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: verifying
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim().toUpperCase();
                        if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter the complete 6-character withdrawal code.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => verifying = true);
                        try {
                          await ref
                              .read(agentDataSourceProvider)
                              .verifyWithdrawalCode(code);
                          await ref
                              .read(walletProvider.notifier)
                              .fetchBalance();
                          ref.invalidate(transactionsProvider);
                          ref.invalidate(agentWithdrawalsProvider);
                          if (!context.mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Payout confirmed. Customer funds settled and Agent wallet credited.',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          setState(() => verifying = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                agentFriendlyError(
                                  error,
                                  fallback:
                                      'Payout code could not be verified. Check the code and try again.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                icon: verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(verifying ? 'Confirming…' : 'Confirm payout'),
              ),
            ],
          ),
        ),
      );
    } finally {
      codeCtrl.dispose();
    }
  }
}

class _CustomerDepositReceipt {
  final String customerId;
  final double amount;
  final DateTime completedAt;

  const _CustomerDepositReceipt({
    required this.customerId,
    required this.amount,
    required this.completedAt,
  });
}

class _CustomerDepositReceiptCard extends StatelessWidget {
  final _CustomerDepositReceipt receipt;

  const _CustomerDepositReceiptCard({required this.receipt});

  @override
  Widget build(BuildContext context) {
    final timestamp = receipt.completedAt.toLocal().toString().split('.').first;
    return Card(
      color: Colors.green.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Customer deposit completed',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '+${receipt.amount.toStringAsFixed(2)} MMK credited',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              'Customer ID: ${receipt.customerId}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Completed: $timestamp',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Customer wallet credited. Agent wallet debited by the same amount.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final Wallet wallet;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;

  const _WalletBalanceCard({
    required this.wallet,
    required this.onDeposit,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    // Agent payout and customer-credit accounting is denominated in MMK.
    const currency = 'MMK';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8050D0), Color(0xFFB8A0F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent wallet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${wallet.balance.toStringAsFixed(2)} $currency',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: ${wallet.availableBalance.toStringAsFixed(2)} $currency',
                  style: const TextStyle(color: Colors.white),
                ),
                if (wallet.reservedBalance > 0)
                  Text(
                    'Reserved: ${wallet.reservedBalance.toStringAsFixed(2)} $currency',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.82)),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDeposit,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Icon(Icons.south, color: Colors.green),
                        SizedBox(height: 4),
                        Text('Deposit', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(
                child: InkWell(
                  onTap: onWithdraw,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: [
                        Icon(Icons.north, color: Colors.deepOrange),
                        SizedBox(height: 4),
                        Text('Withdraw',
                            style: TextStyle(color: Colors.deepOrange)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isCredit ? Colors.green : Colors.deepOrange;
    final sign = transaction.isCredit ? '+' : '-';
    final timestamp =
        transaction.createdAt.toLocal().toString().split('.').first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showTransactionDetails(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Icon(
                    transaction.isCredit ? Icons.south : Icons.north,
                    color: color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.displayType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${transaction.status} • $timestamp',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$sign${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TransactionDetailsSheet(transaction: transaction),
    );
  }
}

class _TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;

  const _TransactionDetailsSheet({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final color = transaction.isCredit ? Colors.green : Colors.deepOrange;
    final sign = transaction.isCredit ? '+' : '-';
    final timestamp =
        transaction.createdAt.toLocal().toString().split('.').first;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            Center(
              child: Text(
                '$sign${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Type', value: transaction.displayType),
            _DetailRow(label: 'Status', value: transaction.status),
            _DetailRow(label: 'Transaction ID', value: transaction.id),
            _DetailRow(label: 'Ledger account', value: transaction.userId),
            _DetailRow(
              label: 'From account',
              value: transaction.fromUserId ??
                  'Not recorded for older transaction',
            ),
            _DetailRow(
              label: 'To account',
              value:
                  transaction.toUserId ?? 'Not recorded for older transaction',
            ),
            _DetailRow(label: 'Currency', value: transaction.currency),
            _DetailRow(label: 'Created', value: timestamp),
            if (transaction.balanceBefore != null)
              _DetailRow(
                label: 'Balance before',
                value:
                    '${transaction.balanceBefore!.toStringAsFixed(2)} ${transaction.currency}',
              ),
            if (transaction.balanceAfter != null)
              _DetailRow(
                label: 'Balance after',
                value:
                    '${transaction.balanceAfter!.toStringAsFixed(2)} ${transaction.currency}',
              ),
            if (transaction.reference?.isNotEmpty == true)
              _DetailRow(label: 'Reference', value: transaction.reference!),
            if (transaction.description?.isNotEmpty == true)
              _DetailRow(label: 'Description', value: transaction.description!),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _AgentNotificationsTab extends ConsumerWidget {
  const _AgentNotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unreadNotificationCountProvider);
        await ref.read(notificationProvider.notifier).loadNotifications();
      },
      child: notifications.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _AgentSkeletonBlock(width: 190, height: 22),
            SizedBox(height: 16),
            _AgentSkeletonList(rows: 4),
          ],
        ),
        error: (error, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 160),
            Icon(Icons.notifications_off_outlined,
                size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('Unable to load notifications')),
          ],
        ),
        data: (items) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Operations alerts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                unreadCount.when(
                  data: (count) => count == 0
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: () async {
                            await ref
                                .read(notificationProvider.notifier)
                                .markAllAsRead();
                            ref.invalidate(unreadNotificationCountProvider);
                          },
                          child: const Text('Mark all read'),
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: Text('No notifications yet')),
              ),
            for (final item in items)
              _AgentNotificationCard(
                item: item,
                onRead: () async {
                  if (!item.isRead) {
                    await ref
                        .read(notificationProvider.notifier)
                        .markAsRead(item.id);
                    ref.invalidate(unreadNotificationCountProvider);
                  }
                },
                onDelete: () async {
                  await ref
                      .read(notificationProvider.notifier)
                      .deleteNotification(item.id);
                  ref.invalidate(unreadNotificationCountProvider);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AgentNotificationCard extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const _AgentNotificationCard({
    required this.item,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: item.isRead
          ? theme.colorScheme.surface
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        onTap: onRead,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          child:
              Icon(_iconForType(item.type), color: theme.colorScheme.primary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${item.message}\\n${_relativeTime(item.createdAt)}'),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Delete',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'deposit':
        return Icons.add_circle_outline;
      case 'withdrawal':
      case 'payout':
        return Icons.payments_outlined;
      case 'support':
        return Icons.support_agent_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _AgentProfileTab extends ConsumerWidget {
  const _AgentProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final initials = (user?.fullName.isNotEmpty == true
            ? user!.fullName
            : user?.username ?? 'A')
        .substring(0, 1)
        .toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  child: Text(initials, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName.isNotEmpty == true
                      ? user!.fullName
                      : user?.username ?? 'Agent',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(user?.email ?? ''),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Agent username'),
                subtitle: Text(user?.username ?? '—'),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Withdrawal location'),
                subtitle: Text(
                  '${user?.region?.isNotEmpty == true ? user!.region : '—'} / ${user?.township?.isNotEmpty == true ? user!.township : '—'}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
            title: const Text('Appearance'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<ThemeMode>(
                value: themeMode == ThemeMode.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                borderRadius: BorderRadius.circular(16),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(authNotifierProvider.notifier).logout(),
          ),
        ),
      ],
    );
  }
}

class _CustomerActivityRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;

  const _CustomerActivityRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _AgentSecurityCard extends ConsumerStatefulWidget {
  const _AgentSecurityCard();

  @override
  ConsumerState<_AgentSecurityCard> createState() => _AgentSecurityCardState();
}

class _AgentSecurityCardState extends ConsumerState<_AgentSecurityCard> {
  bool _busy = false;
  late Future<AgentSecuritySession> _sessionFuture;
  late Future<AgentTwoFactorStatus> _twoFactorFuture;

  @override
  void initState() {
    super.initState();
    final ds = ref.read(agentDataSourceProvider);
    _sessionFuture = ds.getSecuritySession();
    _twoFactorFuture = ds.getTwoFactorStatus();
  }

  @override
  Widget build(BuildContext context) {
    final session = _sessionFuture;
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Security controls'),
            subtitle: Text('PIN, current session, and device revocation'),
          ),
          FutureBuilder<AgentSecuritySession>(
            future: session,
            builder: (context, snapshot) {
              final value = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  title: Text('Checking current session…'),
                );
              }
              return ListTile(
                dense: true,
                leading: Icon(
                  value?.isCurrent == true
                      ? Icons.verified_user_outlined
                      : Icons.warning_amber_outlined,
                  color:
                      value?.isCurrent == true ? Colors.green : Colors.orange,
                ),
                title: Text(value?.isCurrent == true
                    ? 'Current session is active'
                    : 'Session status unavailable'),
                subtitle: value == null
                    ? null
                    : Text('Expires ${_formatDate(value.expiresAt)}'),
              );
            },
          ),
          FutureBuilder<AgentTwoFactorStatus>(
            future: _twoFactorFuture,
            builder: (context, snapshot) {
              final enabled = snapshot.data?.enabled == true;
              return ListTile(
                leading: Icon(
                  enabled
                      ? Icons.phonelink_lock_outlined
                      : Icons.phonelink_setup_outlined,
                  color: enabled ? Colors.green : null,
                ),
                title: Text(enabled
                    ? 'Authenticator 2FA enabled'
                    : 'Set up authenticator 2FA'),
                subtitle: Text(enabled
                    ? 'Use a 6-digit code to manage 2FA'
                    : 'Protect your Agent account with an authenticator app'),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    _busy || snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : () => _manageTwoFactor(enabled),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change security PIN'),
            subtitle:
                const Text('Protect payout confirmation and sensitive actions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : _changePin,
          ),
          ListTile(
            leading:
                const Icon(Icons.devices_other_outlined, color: Colors.red),
            title: const Text('Log out all devices',
                style: TextStyle(color: Colors.red)),
            subtitle: const Text('Revokes all existing sessions immediately'),
            onTap: _busy ? null : _logoutAll,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _manageTwoFactor(bool enabled) async {
    if (enabled) {
      final code = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Disable authenticator 2FA'),
          content: TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration:
                const InputDecoration(labelText: 'Current 6-digit code'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) return;
                try {
                  await ref
                      .read(agentDataSourceProvider)
                      .disableTwoFactor(code.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Could not disable 2FA: $error')),
                    );
                  }
                }
              },
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      code.dispose();
      if (confirmed == true && mounted) {
        setState(() {
          _twoFactorFuture =
              ref.read(agentDataSourceProvider).getTwoFactorStatus();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authenticator 2FA disabled')),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final enrollment =
          await ref.read(agentDataSourceProvider).beginTwoFactorEnrollment();
      if (!mounted) return;
      final code = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Set up authenticator 2FA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Add this account to Google Authenticator, Microsoft Authenticator, or another TOTP app.'),
                const SizedBox(height: 12),
                const Text('Secret key',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SelectableText(enrollment.secret),
                TextButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: enrollment.secret)),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy secret'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration:
                      const InputDecoration(labelText: 'Authenticator code'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) return;
                try {
                  await ref
                      .read(agentDataSourceProvider)
                      .confirmTwoFactor(code.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Could not confirm 2FA: $error')),
                    );
                  }
                }
              },
              child: const Text('Enable 2FA'),
            ),
          ],
        ),
      );
      code.dispose();
      if (confirmed == true && mounted) {
        setState(() {
          _twoFactorFuture =
              ref.read(agentDataSourceProvider).getTwoFactorStatus();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authenticator 2FA enabled')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not begin 2FA setup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePin() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change security PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Current PIN (optional for first setup)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: next,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'New PIN'),
                validator: (value) =>
                    value == null || !RegExp(r'^\d{4,8}$').hasMatch(value)
                        ? 'PIN must contain 4–8 digits'
                        : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Confirm new PIN'),
                validator: (value) =>
                    value != next.text ? 'PINs do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              try {
                await ref.read(agentDataSourceProvider).changeSecurityPin(
                      currentPin: current.text,
                      newPin: next.text,
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not change PIN: $error')),
                  );
                }
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Security PIN changed successfully')),
      );
    }
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out all devices?'),
        content: const Text(
            'All active sessions will be revoked. You will need to sign in again on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revoke sessions'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(agentDataSourceProvider).logoutAllDevices();
      await ref.read(authNotifierProvider.notifier).logout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not revoke sessions: $error')),
        );
        setState(() => _busy = false);
      }
    }
  }
}

class _AgentReconciliationCard extends ConsumerWidget {
  const _AgentReconciliationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentReconciliationProvider);
    final selectedDays = ref.watch(agentEarningsDaysProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const _AgentSkeletonCard(height: 120),
          error: (error, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined),
            title: const Text('Reconciliation unavailable'),
            subtitle: Text(agentFriendlyError(error)),
            trailing: IconButton(
              onPressed: () => ref.invalidate(agentReconciliationProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          data: (report) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Wallet reconciliation',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  DropdownButton<int>(
                    value: selectedDays,
                    underline: const SizedBox.shrink(),
                    items: const [7, 30, 90]
                        .map((days) => DropdownMenuItem<int>(
                              value: days,
                              child: Text('$days days'),
                            ))
                        .toList(),
                    onChanged: (days) {
                      if (days != null) {
                        ref.read(agentEarningsDaysProvider.notifier).state =
                            days;
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    report.reconciled
                        ? Icons.verified_outlined
                        : Icons.warning_amber_outlined,
                    color: report.reconciled ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.reconciled
                          ? 'Wallet and ledger are reconciled'
                          : 'Review discrepancy before settlement',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _copyCsv(context, ref, selectedDays),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AgentReconciliationMetric(
                      label: 'Wallet balance',
                      value:
                          '${report.walletBalance.toStringAsFixed(0)} ${report.currency}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentReconciliationMetric(
                      label: 'Ledger change',
                      value:
                          '${report.ledgerChange.toStringAsFixed(0)} ${report.currency}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AgentReconciliationMetric(
                      label: 'Difference',
                      value:
                          '${report.difference.toStringAsFixed(2)} ${report.currency}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentReconciliationMetric(
                      label: 'Pending payouts',
                      value: report.pendingPayouts.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Settlement net ${report.netSettlement.toStringAsFixed(0)} ${report.currency} • ${report.transactionCount} transactions',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copyCsv(BuildContext context, WidgetRef ref, int days) async {
    try {
      final csv = await ref
          .read(agentDataSourceProvider)
          .getReconciliationCSV(days: days);
      await Clipboard.setData(ClipboardData(text: csv));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Reconciliation CSV copied to clipboard')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(agentFriendlyError(error,
                  fallback: 'Reconciliation export is unavailable.'))),
        );
      }
    }
  }
}

class _AgentReconciliationMetric extends StatelessWidget {
  final String label;
  final String value;

  const _AgentReconciliationMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AgentCommissionCard extends ConsumerWidget {
  const _AgentCommissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentCommissionStatementProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const _AgentSkeletonCard(height: 150),
          error: (error, _) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.percent_outlined),
            title: const Text('Commission statement unavailable'),
            subtitle: Text(agentFriendlyError(error)),
            trailing: IconButton(
              onPressed: () => ref.invalidate(agentCommissionStatementProvider),
              icon: const Icon(Icons.refresh),
            ),
          ),
          data: (statement) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commission statement',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.receipt_long_outlined),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Configured rates are applied only to settled activity.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _AgentCommissionMetric(
                      label: 'Deposit rate',
                      value:
                          '${statement.depositRatePercent.toStringAsFixed(2)}%',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentCommissionMetric(
                      label: 'Payout rate',
                      value:
                          '${statement.payoutRatePercent.toStringAsFixed(2)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _AgentCommissionMetric(
                      label: 'Commission earned',
                      value:
                          '${statement.commissionAmount.toStringAsFixed(0)} ${statement.earnings.currency}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AgentCommissionMetric(
                      label: 'Net after commission',
                      value:
                          '${statement.netAfterCommission.toStringAsFixed(0)} ${statement.earnings.currency}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCommissionMetric extends StatelessWidget {
  final String label;
  final String value;

  const _AgentCommissionMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AgentSkeletonBlock extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const _AgentSkeletonBlock({
    this.height = 14,
    this.width,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _AgentSkeletonCard extends StatelessWidget {
  final int rows;
  final double height;

  const _AgentSkeletonCard({this.rows = 3, this.height = 118});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const _AgentSkeletonBlock(width: 150, height: 18),
              for (var index = 0; index < rows; index++)
                _AgentSkeletonBlock(
                  width: index.isEven ? 240 : 190,
                  height: 13,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentSkeletonList extends StatelessWidget {
  final int rows;

  const _AgentSkeletonList({this.rows = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < rows; index++)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const _AgentSkeletonBlock(
                    width: 44,
                    height: 44,
                    radius: 22,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AgentSkeletonBlock(width: 150, height: 15),
                        SizedBox(height: 10),
                        _AgentSkeletonBlock(width: 110, height: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _AgentSkeletonBlock(
                      width: index.isEven ? 82 : 62, height: 15),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class AgentSplashScreen extends StatelessWidget {
  const AgentSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/cloud9_agent_icon.png',
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Cloud 9 Agent',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Operations made simple',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
