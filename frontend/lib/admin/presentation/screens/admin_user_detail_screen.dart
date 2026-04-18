import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                        Text('Current Balance: ${user.balance.toStringAsFixed(2)}'),
                        Text('Registered: ${dateFmt.format(user.createdAt)}'),
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
                        return const Center(child: Text('No activity logs yet.'));
                      }
                      return ListView.separated(
                        itemCount: res.transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = res.transactions[index];
                          return ListTile(
                            title: Text('${tx.type} | ${tx.amount.toStringAsFixed(2)} ${tx.currency}'),
                            subtitle: Text(
                              '${tx.status} | ${dateFmt.format(tx.createdAt)}\n${tx.description}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      );
                    },
                    error: (e, _) => Center(child: Text('Failed to load activity: $e')),
                    loading: () => const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
            );
          },
          error: (e, _) => Center(child: Text('Failed to load user detail: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
