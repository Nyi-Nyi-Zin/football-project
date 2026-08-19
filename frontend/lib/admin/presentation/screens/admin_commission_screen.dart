import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_ops_models.dart';
import '../../data/admin_remote_datasource.dart';
import '../providers/admin_provider.dart';

class AdminCommissionScreen extends ConsumerStatefulWidget {
  const AdminCommissionScreen({super.key});

  @override
  ConsumerState<AdminCommissionScreen> createState() =>
      _AdminCommissionScreenState();
}

class _AdminCommissionScreenState extends ConsumerState<AdminCommissionScreen> {
  String? _selectedAgentId;
  final _depositController = TextEditingController();
  final _payoutController = TextEditingController();
  String? _initializedFor;
  bool _saving = false;

  @override
  void dispose() {
    _depositController.dispose();
    _payoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider(const UserQuery()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent commission rules'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(usersProvider(const UserQuery())),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: usersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load Agents: $error')),
        data: (response) {
          final agents =
              response.users.where((user) => user.role == 'agent').toList();
          if (agents.isEmpty) {
            return const Center(child: Text('No Agent accounts found'));
          }
          final selectedId = _selectedAgentId != null &&
                  agents.any((agent) => agent.id == _selectedAgentId)
              ? _selectedAgentId!
              : agents.first.id;
          final ruleState = ref.watch(adminCommissionRuleProvider(selectedId));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: selectedId,
                decoration: const InputDecoration(labelText: 'Agent account'),
                items: agents
                    .map((agent) => DropdownMenuItem(
                          value: agent.id,
                          child: Text(
                              '${agent.fullName.isEmpty ? agent.username : agent.fullName} (${agent.username})'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedAgentId = value),
              ),
              const SizedBox(height: 18),
              ruleState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('Could not load commission rule: $error'),
                data: (rule) => _buildRuleForm(rule, selectedId),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleForm(AdminAgentCommissionRule rule, String agentId) {
    if (_initializedFor != agentId) {
      _initializedFor = agentId;
      _depositController.text = (rule.depositRateBps / 100).toStringAsFixed(2);
      _payoutController.text = (rule.payoutRateBps / 100).toStringAsFixed(2);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settlement commission',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'Rates are stored as basis points and applied only to settled Agent activity in ${rule.currency}.'),
            const SizedBox(height: 18),
            TextField(
              controller: _depositController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Deposit commission (%)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _payoutController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Payout commission (%)'),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : () => _saveRule(agentId),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save rule'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRule(String agentId) async {
    final deposit = double.tryParse(_depositController.text.trim());
    final payout = double.tryParse(_payoutController.text.trim());
    if (deposit == null ||
        payout == null ||
        deposit < 0 ||
        payout < 0 ||
        deposit > 100 ||
        payout > 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rates must be between 0 and 100 percent')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(adminDatasourceProvider).updateAgentCommissionRule(
            agentId: agentId,
            depositRateBps: (deposit * 100).round(),
            payoutRateBps: (payout * 100).round(),
          );
      ref.invalidate(adminCommissionRuleProvider(agentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Commission rule saved')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not save rule: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
