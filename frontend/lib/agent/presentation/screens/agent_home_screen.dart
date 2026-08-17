import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/payment/domain/entities/payment_entity.dart';
import '../../../features/payment/presentation/providers/payment_provider.dart';
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
    _selectedIndex = widget.initialIndex.clamp(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    const titles = ['Agent Wallet', 'Payouts', 'Profile'];
    final pages = <Widget>[
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

class _AgentWalletTab extends ConsumerWidget {
  const _AgentWalletTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const SizedBox(height: 22),
          Text(
            'Recent transactions',
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
                          Navigator.of(dialogContext).pop();
                          ref.invalidate(transactionsProvider);
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
    final currency = wallet.currency.isEmpty ? 'MMK' : wallet.currency;
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            transaction.isCredit ? Icons.south : Icons.north,
            color: color,
          ),
        ),
        title: Text(transaction.displayType),
        subtitle: Text(
          '${transaction.status} • ${transaction.createdAt.toLocal().toString().split('.').first}',
        ),
        trailing: Text(
          '$sign${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
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
