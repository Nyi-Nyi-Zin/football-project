import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/payment/domain/entities/payment_entity.dart';
import '../../../features/payment/presentation/providers/payment_provider.dart';
import '../../data/agent_models.dart';
import '../providers/agent_provider.dart';
import 'agent_withdrawals_screen.dart';

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
    _selectedIndex = widget.initialIndex.clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'Agent Home',
      'Customers',
      'Agent Wallet',
      'Payouts',
      'Profile'
    ];
    final pages = <Widget>[
      const _AgentDashboardTab(),
      const _AgentCustomersTab(),
      const _AgentWalletTab(),
      const AgentWithdrawalsScreen(embedded: true),
      const _AgentProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Payouts',
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
}

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
                child: Text('Unable to load dashboard metrics: $error'),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Unable to load activity: $error'),
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
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
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
                'Agent operations',
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 40),
                    const SizedBox(height: 8),
                    Text('Unable to load customers: $error'),
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
            loading: () => const Card(
              child: SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 8),
                    Text('Unable to load wallet: $error'),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Unable to load transactions: $error'),
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
    final uuidV4Pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
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
                      helperText: 'Paste the complete UUID (36 characters)',
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
                        final customerId = customerIdCtrl.text.trim();
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (!uuidV4Pattern.hasMatch(customerId)) {
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
                                'Customer deposit failed: $error',
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
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    var saving = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Withdraw funds'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Available: ${wallet.availableBalance.toStringAsFixed(2)} MMK',
                    ),
                  ),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      suffixText: 'MMK',
                    ),
                  ),
                  TextField(
                    controller: accountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Payout account details',
                      hintText: 'Bank or wallet account',
                    ),
                    maxLines: 2,
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
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid amount.')),
                          );
                          return;
                        }
                        if (amount > wallet.availableBalance) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Insufficient balance. Available: ${wallet.availableBalance.toStringAsFixed(2)} MMK',
                              ),
                            ),
                          );
                          return;
                        }
                        if (accountCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Enter payout account details.')),
                          );
                          return;
                        }
                        setState(() => saving = true);
                        final submission =
                            await ref.read(walletProvider.notifier).withdraw(
                                  amount: amount,
                                  accountDetails: accountCtrl.text.trim(),
                                  currency: 'MMK',
                                );
                        if (!context.mounted) return;
                        if (submission == null) {
                          setState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Withdrawal failed. Please check your balance and try again.')),
                          );
                          return;
                        }
                        Navigator.of(dialogContext).pop();
                        ref.invalidate(transactionsProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Withdrawal request submitted.')),
                        );
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit withdrawal'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amountCtrl.dispose();
      accountCtrl.dispose();
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

class _AgentProfileTab extends ConsumerWidget {
  const _AgentProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull;
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
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: const Text('Custom payout code'),
                subtitle: Text(user?.customCode?.isNotEmpty == true
                    ? user!.customCode!
                    : 'Auto-generated code'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Edit withdrawal profile'),
            subtitle:
                const Text('Use the Payouts tab to update code and location.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Open the Payouts tab to edit your profile.')),
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
