import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/payment_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      'Total Balance',
                      style: TextStyle(
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
                        style: TextStyle(fontSize: 32, color: AppTheme.errorColor),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDepositDialog(context, ref),
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Deposit'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showWithdrawalDialog(context, ref),
                            icon: const Icon(Icons.arrow_circle_up),
                            label: const Text('Withdraw'),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                'Recent Transactions',
                style: TextStyle(
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
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No transactions yet.',
                            style: TextStyle(color: AppTheme.textSecondary),
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
                                  ? AppTheme.successColor.withOpacity(0.2) 
                                  : AppTheme.errorColor.withOpacity(0.2),
                              child: Icon(
                                isCredit ? Icons.add : Icons.remove,
                                color: isCredit ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                            ),
                            title: Text(
                              tx.type.toUpperCase().replaceAll('_', ' '),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${tx.createdAt.month}/${tx.createdAt.day}/${tx.createdAt.year}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: Text(
                              '${isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(2)} MMK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isCredit ? AppTheme.successColor : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )),
                  error: (_, __) => const Center(child: Text('Error loading transactions')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog(BuildContext context, WidgetRef ref) {
    _showTxDialog(context, ref, 'Deposit', (amount) async {
      final success = await ref.read(walletProvider.notifier).deposit(amount);
      if (success) {
        ref.invalidate(transactionsProvider);
      }
      return success;
    });
  }

  void _showWithdrawalDialog(BuildContext context, WidgetRef ref) {
     _showTxDialog(context, ref, 'Withdraw', (amount) async {
      final success = await ref.read(walletProvider.notifier).withdraw(amount);
      if (success) {
        ref.invalidate(transactionsProvider);
      }
      return success;
    });
  }

  void _showTxDialog(BuildContext context, WidgetRef ref, String action, Future<bool> Function(double) onSubmit) {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text('$action Funds'),
              content: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (MMK)',
                  filled: true,
                  fillColor: AppTheme.darkBg,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    final amount = double.tryParse(controller.text);
                    if (amount == null || amount <= 0) return;
                    
                    setState(() => isLoading = true);
                    final success = await onSubmit(amount);
                    setState(() => isLoading = false);
                    
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '$action successful!' : '$action failed. Check limits/balance.'),
                          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                        )
                      );
                    }
                  },
                  child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(action),
                )
              ],
            );
          }
        );
      }
    );
  }
}
