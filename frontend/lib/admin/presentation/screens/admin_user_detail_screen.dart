import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_remote_datasource.dart';
import '../providers/admin_provider.dart';

class AdminUserDetailScreen extends ConsumerWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailProvider(userId));
    final txAsync = ref.watch(
      transactionsProvider(
        TxQuery(userId: userId, page: 1, limit: 20),
      ),
    );
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('User Detail & Activity Logs')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: userAsync.when(
          data: (user) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 12,
                      children: [
                        SelectableText('User ID: ${user.id}'),
                        Text('Username: ${user.username}'),
                        Text('Email: ${user.email}'),
                        Text('Role: ${user.role}'),
                        Text('Status: ${user.status}'),
                        Text(
                            'Current Balance: ${user.balance.toStringAsFixed(2)}'),
                        Text('Registered: ${dateFmt.format(user.createdAt)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (user.role != 'admin')
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Account controls:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (user.status != 'active')
                            FilledButton.tonal(
                              onPressed: () =>
                                  _changeStatus(context, ref, 'active'),
                              child: const Text('Activate'),
                            ),
                          if (user.status != 'suspended')
                            OutlinedButton(
                              onPressed: () =>
                                  _changeStatus(context, ref, 'suspended'),
                              child: const Text('Suspend'),
                            ),
                          if (user.status != 'blocked')
                            OutlinedButton(
                              onPressed: () =>
                                  _changeStatus(context, ref, 'blocked'),
                              child: const Text('Block'),
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Activity Logs (Transactions)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: txAsync.when(
                    data: (res) {
                      if (res.transactions.isEmpty) {
                        return const Center(
                            child: Text('No activity logs yet.'));
                      }
                      return ListView.separated(
                        itemCount: res.transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = res.transactions[index];
                          return ListTile(
                            title: Text(
                                '${tx.type} | ${tx.amount.toStringAsFixed(2)} ${tx.currency}'),
                            subtitle: Text(
                              '${tx.status} | ${dateFmt.format(tx.createdAt)}\n${tx.description}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      );
                    },
                    error: (e, _) =>
                        Center(child: Text('Failed to load activity: $e')),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            );
          },
          error: (e, _) =>
              Center(child: Text('Failed to load user detail: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    String status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text('${status[0].toUpperCase()}${status.substring(1)} account?'),
        content: Text('This will change the user status to "$status".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(adminDatasourceProvider).updateUserStatus(
            userId: userId,
            status: status,
          );
      ref.invalidate(userDetailProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User status changed to $status.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status update failed: $error')),
        );
      }
    }
  }
}
