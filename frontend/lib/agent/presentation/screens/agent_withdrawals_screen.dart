import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/agent_provider.dart';

class AgentWithdrawalsScreen extends ConsumerStatefulWidget {
  const AgentWithdrawalsScreen({super.key});

  @override
  ConsumerState<AgentWithdrawalsScreen> createState() =>
      _AgentWithdrawalsScreenState();
}

class _AgentWithdrawalsScreenState
    extends ConsumerState<AgentWithdrawalsScreen> {
  final _codeCtrl = TextEditingController();
  final _customCodeCtrl = TextEditingController();
  bool _submitting = false;
  bool _savingCustomCode = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _customCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(agentWithdrawalsProvider);
    final status = ref.watch(agentWithdrawStatusProvider);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Withdrawals'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const Text(
                      'Set Custom Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customCodeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 10,
                            decoration: const InputDecoration(
                              labelText: 'Custom code (3-10 chars)',
                              counterText: '',
                              helperText: 'Leave empty to use auto-generated codes',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _savingCustomCode ? null : _saveCustomCode,
                          child: _savingCustomCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Verify Withdrawal Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              labelText: 'Enter 6-character code',
                              counterText: '',
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _submitting ? null : _verifyCode,
                          icon: const Icon(Icons.verified),
                          label: const Text('Verify & Approve'),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(agentWithdrawalsProvider),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Status Filter:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(
                                value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(
                                value: 'approved', child: Text('Approved')),
                            DropdownMenuItem(
                                value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            ref
                                .read(agentWithdrawStatusProvider.notifier)
                                .state = v;
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncRows.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Center(
                        child: Text('No assigned withdrawals.'));
                  }
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return ListTile(
                        title: SelectableText(
                          'Customer: ${row.customerId} | ${row.amount.toStringAsFixed(2)} ${row.currency}',
                        ),
                        subtitle: Text(
                          'Request: ${row.requestStatus} | Tx: ${row.transactionStatus}\n${dateFmt.format(row.createdAt)}',
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: row.customerId));
                            if (!mounted) return;
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                  content: Text('Customer ID copied')),
                            );
                          },
                          child: const Text('Copy ID'),
                        ),
                      );
                    },
                  );
                },
                error: (e, _) =>
                    Center(child: Text('Failed to load assigned requests: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code must be 6 characters')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(agentDataSourceProvider).verifyWithdrawalCode(code);
      _codeCtrl.clear();
      ref.invalidate(agentWithdrawalsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Withdrawal approved and funds deducted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveCustomCode() async {
    final customCode = _customCodeCtrl.text.trim().toUpperCase();
    if (customCode.isNotEmpty && (customCode.length < 3 || customCode.length > 10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom code must be 3-10 characters')),
      );
      return;
    }
    setState(() => _savingCustomCode = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(
        customCode: customCode.isEmpty ? null : customCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom code saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save custom code: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingCustomCode = false);
    }
  }
}
