import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/payment_entity.dart';
import '../providers/payment_provider.dart';
import 'withdrawal_screen.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.tr('wallet'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(walletProvider.notifier).fetchBalance();
              // Invalidate transactions so they reload
              ref.invalidate(transactionsProvider);
            },
          )
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: () async {
          await ref.read(walletProvider.notifier).fetchBalance();
          ref.invalidate(transactionsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      context.l10n.tr('totalBalance'),
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    walletState.when(
                      data: (w) => Column(
                        children: [
                          Text(
                            '${w.availableBalance.toStringAsFixed(2)} MMK',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const Text(
                            'Available balance',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (w.reservedBalance > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Held pending withdrawals: ${w.reservedBalance.toStringAsFixed(2)} MMK',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Total balance: ${w.balance.toStringAsFixed(2)} MMK',
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, __) => Column(
                        children: [
                          const Text(
                            'Unable to load balance',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.errorColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _walletErrorMessage(error),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(walletProvider.notifier)
                                .fetchBalance(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _showDepositDialog(context, ref),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Deposit'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WithdrawalScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.arrow_circle_up),
                            label: Text(context.l10n.tr('withdraw')),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Transactions Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                context.l10n.tr('recentTransactions'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),

            // Transactions List
            Consumer(
              builder: (context, ref, child) {
                final txState = ref.watch(transactionsProvider);

                return txState.when(
                  data: (transactions) {
                    if (transactions.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            context.l10n.tr('noTransactions'),
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isCredit = tx.isCredit;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCredit
                                  ? AppTheme.successColor.withValues(alpha: 0.2)
                                  : AppTheme.errorColor.withValues(alpha: 0.2),
                              child: Icon(
                                isCredit ? Icons.add : Icons.remove,
                                color: isCredit
                                    ? AppTheme.successColor
                                    : AppTheme.errorColor,
                              ),
                            ),
                            title: Text(
                              tx.type.toUpperCase().replaceAll('_', ' '),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${tx.createdAt.month}/${tx.createdAt.day}/${tx.createdAt.year}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} MMK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isCredit
                                        ? AppTheme.successColor
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                            onTap: () => _showTransactionDetails(context, tx),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )),
                  error: (_, __) => Center(
                      child: Text(context.l10n.tr('errorLoadingTransactions'))),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction tx) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Status', tx.status.toUpperCase()),
      MapEntry('Transaction ID', tx.id),
      MapEntry('Created', tx.createdAt.toLocal().toString()),
      if (tx.description?.isNotEmpty == true)
        MapEntry('Description', tx.description!),
      if (tx.reference?.isNotEmpty == true)
        MapEntry('Reference', tx.reference!),
      if (tx.fromUserId?.isNotEmpty == true)
        MapEntry('From account', tx.fromUserId!),
      if (tx.toUserId?.isNotEmpty == true) MapEntry('To account', tx.toUserId!),
      if (tx.balanceBefore != null)
        MapEntry(
            'Balance before', '${tx.balanceBefore!.toStringAsFixed(2)} MMK'),
      if (tx.balanceAfter != null)
        MapEntry('Balance after', '${tx.balanceAfter!.toStringAsFixed(2)} MMK'),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                tx.displayType,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${tx.isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                style: TextStyle(
                  color: tx.isCredit
                      ? AppTheme.successColor
                      : AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Divider(height: 24),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 118,
                        child: Text(
                          row.key,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                      Expanded(child: SelectableText(row.value)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _walletErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('401') || message.contains('unauthorized')) {
      return 'Your session may have expired. Please log in again and retry.';
    }
    return 'Please retry in a moment.';
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    bool isLoading = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Deposit funds'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Demo deposit credits your wallet immediately. Connect a real payment provider before production money is accepted.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (MMK)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amount =
                              double.tryParse(amountCtrl.text.trim());
                          if (amount == null || amount <= 0) return;
                          setState(() => isLoading = true);
                          final transaction = await ref
                              .read(walletProvider.notifier)
                              .deposit(amount: amount);
                          if (!dialogContext.mounted) return;
                          setState(() => isLoading = false);
                          Navigator.pop(dialogContext);
                          if (transaction != null) {
                            ref.invalidate(transactionsProvider);
                            await showDialog<void>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Deposit successful'),
                                content: Text(
                                  '${amount.toStringAsFixed(2)} MMK was added to your wallet.',
                                ),
                                actions: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Done'),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Deposit failed. Please retry.'),
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Deposit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Legacy helper retained for compatibility with older wallet navigation.
  // ignore: unused_element
  void _showWithdrawalDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(ctx).cardColor,
              title: Text(
                  '${context.l10n.tr('withdraw')} ${context.l10n.tr("funds")}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.tr('amountMmk'),
                      filled: true,
                      fillColor: Theme.of(ctx).scaffoldBackgroundColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: accountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account details',
                      helperText: 'Phone/account info for cashout',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    context.l10n.tr('cancel'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text);
                          final accountDetails = accountCtrl.text.trim();
                          if (amount == null ||
                              amount <= 0 ||
                              accountDetails.isEmpty) {
                            return;
                          }

                          setState(() => isLoading = true);
                          final submission =
                              await ref.read(walletProvider.notifier).withdraw(
                                    amount: amount,
                                    accountDetails: accountDetails,
                                  );
                          setState(() => isLoading = false);

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            if (submission != null) {
                              ref.invalidate(transactionsProvider);
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title:
                                      const Text('Withdrawal Code Generated'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                          'Give this code to your assigned agent:'),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        submission.verificationCode,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Assigned agent: ${submission.assignedAgentId}'),
                                      Text(
                                          'Status: ${submission.requestStatus}'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(
                                              text:
                                                  submission.verificationCode),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text('Code copied')),
                                          );
                                        }
                                      },
                                      child: const Text('Copy Code'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${context.l10n.tr('withdraw')} ${context.l10n.tr("failedCheckLimits")}',
                                  ),
                                  backgroundColor: AppTheme.errorColor,
                                ),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(context.l10n.tr('withdraw')),
                )
              ],
            );
          });
        });
  }
}
