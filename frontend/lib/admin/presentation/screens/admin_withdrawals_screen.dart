import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_remote_datasource.dart';
import '../providers/admin_provider.dart';

class AdminWithdrawalsScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends ConsumerState<AdminWithdrawalsScreen> {
  String _status = 'pending';
  int _page = 1;
  bool _loadingAction = false;

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(
      withdrawalsProvider(WithdrawalQuery(status: _status, page: _page, limit: 20)),
    );
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Withdrawal Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'completed', child: Text('Approved')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Rejected')),
                    DropdownMenuItem(value: '', child: Text('All')),
                  ],
                  onChanged: (v) => setState(() {
                    _status = v ?? 'pending';
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _page = 1),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: asyncRows.when(
                data: (res) {
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: res.transactions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = res.transactions[index];
                            final isPending = tx.status == 'pending';
                            return ListTile(
                              title: SelectableText(
                                '${tx.userId} | ${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                              ),
                              subtitle: Text(
                                '${tx.description}\n${dateFmt.format(tx.createdAt)} | ${tx.status}',
                              ),
                              isThreeLine: true,
                              trailing: isPending
                                  ? Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton(
                                          onPressed: _loadingAction ? null : () => _approve(tx.id),
                                          child: const Text('Approve'),
                                        ),
                                        ElevatedButton(
                                          onPressed: _loadingAction ? null : () => _reject(tx.id),
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _page > 1 ? () => setState(() => _page--) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page $_page / ${res.lastPage}'),
                          IconButton(
                            onPressed: _page < res.lastPage ? () => setState(() => _page++) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                error: (e, _) => Center(child: Text('Failed to load withdrawals: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(String txId) async {
    setState(() => _loadingAction = true);
    try {
      await ref.read(adminDatasourceProvider).approveWithdrawal(txId);
      ref.invalidate(withdrawalsProvider(WithdrawalQuery(status: _status, page: _page, limit: 20)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal approved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _reject(String txId) async {
    setState(() => _loadingAction = true);
    try {
      await ref.read(adminDatasourceProvider).rejectWithdrawal(txId, reason: 'Rejected by admin');
      ref.invalidate(withdrawalsProvider(WithdrawalQuery(status: _status, page: _page, limit: 20)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }
}
