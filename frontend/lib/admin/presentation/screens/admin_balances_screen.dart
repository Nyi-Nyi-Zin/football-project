import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_remote_datasource.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
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
  final _uuidV4Pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

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
                        maxLength: 36,
                        decoration: const InputDecoration(
                          labelText: 'User ID',
                          helperText: 'Paste the complete UUID (36 characters)',
                          counterText: '',
                        ),
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
    final userId = _userIdCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (!_uuidV4Pattern.hasMatch(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Enter the complete User ID UUID, for example 8-4-4-4-12 characters.'),
        ),
      );
      return;
    }
    if (amount == null || amount <= 0 || _reasonCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill user id, amount and reason.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(adminDatasourceProvider).adjustBalance(
            userId: userId,
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
      if (e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Admin permission required. Please sign in again with an admin account.'),
          ),
        );
        await ref.read(authNotifierProvider.notifier).logout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adjustment failed: ${_errorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final body = data['error'];
        if (body is Map<String, dynamic> && body['message'] is String) {
          return body['message'] as String;
        }
      }
    }
    return error.toString();
  }
}
