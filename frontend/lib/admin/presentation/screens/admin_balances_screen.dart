import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_remote_datasource.dart';
import '../providers/admin_provider.dart';

class AdminBalancesScreen extends ConsumerStatefulWidget {
  const AdminBalancesScreen({super.key});

  @override
  ConsumerState<AdminBalancesScreen> createState() =>
      _AdminBalancesScreenState();
}

class _AdminBalancesScreenState extends ConsumerState<AdminBalancesScreen> {
  final _userIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _action = 'credit';
  bool _submitting = false;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(
      transactionsProvider(
        const TxQuery(type: 'deposit', status: 'completed', page: 1, limit: 50),
      ),
    );
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Balance Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _userIdCtrl,
                        decoration: const InputDecoration(labelText: 'User ID'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: _action,
                        items: const [
                          DropdownMenuItem(
                              value: 'credit', child: Text('Credit')),
                          DropdownMenuItem(
                              value: 'debit', child: Text('Debit')),
                        ],
                        onChanged: (v) =>
                            setState(() => _action = v ?? 'credit'),
                        decoration: const InputDecoration(labelText: 'Action'),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _reasonCtrl,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _submitting ? null : _submitAdjustment,
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: txAsync.when(
                data: (res) {
                  return ListView.separated(
                    itemCount: res.transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tx = res.transactions[index];
                      return ListTile(
                        title: SelectableText(
                          '${tx.userId} | ${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                        ),
                        subtitle: Text(
                          '${tx.description} | ${dateFmt.format(tx.createdAt)}',
                        ),
                        trailing: Text(tx.status),
                      );
                    },
                  );
                },
                error: (e, _) =>
                    Center(child: Text('Failed to load history: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAdjustment() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_userIdCtrl.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill user id, amount and reason.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(adminDatasourceProvider).adjustBalance(
            userId: _userIdCtrl.text.trim(),
            amount: amount,
            action: _action,
            reason: _reasonCtrl.text.trim(),
          );
      ref.invalidate(transactionsProvider(const TxQuery(
          type: 'deposit', status: 'completed', page: 1, limit: 50)));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balance adjusted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustment failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
