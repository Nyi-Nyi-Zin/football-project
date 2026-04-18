import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/payment_provider.dart';

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
                      data: (w) => Text(
                        '${w.balance.toStringAsFixed(2)} MMK',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text(
                        'Error',
                        style:
                            TextStyle(fontSize: 32, color: AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _showWithdrawalDialog(context, ref),
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
                            trailing: Text(
                              '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} MMK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isCredit
                                    ? AppTheme.successColor
                                    : AppTheme.textPrimary,
                              ),
                            ),
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

  void _showWithdrawalDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
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
                      fillColor: AppTheme.darkBg,
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
