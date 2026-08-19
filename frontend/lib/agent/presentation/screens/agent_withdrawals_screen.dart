import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/payment/presentation/providers/payment_provider.dart';
import '../../../features/payment/presentation/providers/withdrawal_provider.dart';
import '../../core/agent_error_message.dart';
import '../providers/agent_provider.dart';

class AgentWithdrawalsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AgentWithdrawalsScreen({super.key, this.embedded = false});

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
  bool _savingAgentLocation = false;
  bool _locationInitialized = false;
  String? _selectedAgentRegion;
  String? _selectedAgentTownship;

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
    final user = ref.watch(authNotifierProvider).valueOrNull;
    if (user != null && !_locationInitialized) {
      _locationInitialized = true;
      _customCodeCtrl.text = user.customCode ?? '';
      _selectedAgentRegion = user.region;
      _selectedAgentTownship = user.township;
    }
    final regionsAsync = ref.watch(agentRegionsProvider);
    final townshipsAsync = _selectedAgentRegion == null
        ? const AsyncValue<List<String>>.data(<String>[])
        : ref.watch(agentTownshipsProvider(_selectedAgentRegion!));
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Agent Withdrawals'),
              actions: [
                IconButton(
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).logout(),
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
                              helperText:
                                  'Leave empty to use auto-generated codes',
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Withdrawal Location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    regionsAsync.when(
                      data: (regions) => DropdownButtonFormField<String>(
                        value: regions.contains(_selectedAgentRegion)
                            ? _selectedAgentRegion
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Region / State',
                          border: OutlineInputBorder(),
                        ),
                        items: regions
                            .map((region) => DropdownMenuItem(
                                  value: region,
                                  child: Text(region),
                                ))
                            .toList(),
                        onChanged: (region) {
                          setState(() {
                            _selectedAgentRegion = region;
                            _selectedAgentTownship = null;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        agentFriendlyError(error,
                            fallback: 'Regions are unavailable.'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    townshipsAsync.when(
                      data: (townships) => DropdownButtonFormField<String>(
                        value: townships.contains(_selectedAgentTownship)
                            ? _selectedAgentTownship
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Township',
                          border: OutlineInputBorder(),
                        ),
                        items: townships
                            .map((township) => DropdownMenuItem(
                                  value: township,
                                  child: Text(township),
                                ))
                            .toList(),
                        onChanged: _selectedAgentRegion == null
                            ? null
                            : (township) => setState(
                                  () => _selectedAgentTownship = township,
                                ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(
                        agentFriendlyError(error,
                            fallback: 'Townships are unavailable.'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed:
                            _savingAgentLocation ? null : _saveAgentLocation,
                        icon: _savingAgentLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_on_outlined),
                        label: const Text('Save Location'),
                      ),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Confirm Payout Code',
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
                          label: const Text('Confirm Payout'),
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
                          'Customer: ${row.customerName.isEmpty ? row.customerId : row.customerName} | ${row.amount.toStringAsFixed(2)} ${row.currency}',
                        ),
                        subtitle: Text(
                          'Request: ${row.requestStatus} | Tx: ${row.transactionStatus}\n${dateFmt.format(row.createdAt)}${row.requestStatus == 'pending' ? '\n${_expiryLabel(row.expiresAt)}' : ''}',
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
                error: (error, _) => Center(
                  child: Text(
                    agentFriendlyError(error,
                        fallback: 'Payout requests are unavailable.'),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _expiryLabel(DateTime? expiresAt) {
    if (expiresAt == null) return 'No expiry set';
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return 'Request expired';
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return hours > 0
        ? 'Expires in ${hours}h ${minutes}m'
        : 'Expires in ${minutes}m ${remaining.inSeconds.remainder(60)}s';
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
      await ref.read(walletProvider.notifier).fetchBalance();
      await ref.refresh(transactionsProvider.future).then<void>((_) {});
      _codeCtrl.clear();
      ref.invalidate(agentWithdrawalsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payout confirmed. Customer balance settled and agent wallet credited.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            agentFriendlyError(e,
                fallback: 'Payout code could not be verified.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveAgentLocation() async {
    final region = _selectedAgentRegion;
    final township = _selectedAgentTownship;
    if (region == null || township == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both region and township')),
      );
      return;
    }
    setState(() => _savingAgentLocation = true);
    try {
      final result =
          await ref.read(authNotifierProvider.notifier).updateProfile(
                region: region,
                township: township,
                location: township,
              );
      if (!mounted) return;
      result.fold(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save location: ${failure.message}')),
        ),
        (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Withdrawal location saved successfully')),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingAgentLocation = false);
    }
  }

  Future<void> _saveCustomCode() async {
    final customCode = _customCodeCtrl.text.trim().toUpperCase();
    if (customCode.isNotEmpty &&
        (customCode.length < 3 || customCode.length > 10)) {
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
        SnackBar(
          content: Text(
            agentFriendlyError(e,
                fallback: 'Custom payout code could not be saved.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingCustomCode = false);
    }
  }
}
