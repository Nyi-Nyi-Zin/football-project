import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/payment_provider.dart';
import '../providers/withdrawal_provider.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _accountDetailsController = TextEditingController();
  String? _selectedRegion;
  String? _selectedTownship;
  String? _selectedAgentId;
  String? _selectedAgentName;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _accountDetailsController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_amountController.text);
    final region = _selectedRegion?.trim() ?? '';
    final township = _selectedTownship?.trim() ?? '';
    final accountDetails = _accountDetailsController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final wallet = ref.read(walletProvider).valueOrNull;
    if (wallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Balance is still loading. Please retry.')),
      );
      return;
    }
    final availableBalance = wallet.availableBalance;
    if (amount > availableBalance + 0.000001) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient available balance. Available: ${availableBalance.toStringAsFixed(2)} MMK',
          ),
        ),
      );
      return;
    }

    if (region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a region or state')),
      );
      return;
    }

    if (township.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a township')),
      );
      return;
    }

    if (_selectedAgentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an agent')),
      );
      return;
    }

    if (accountDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter account details')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ref.read(withdrawalProvider.notifier).createWithdrawal(
          amount: amount,
          region: region,
          township: township,
          location: township,
          agentId: _selectedAgentId!,
          accountDetails: accountDetails,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (mounted) {
      result.fold(
        (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(error.message),
                backgroundColor: AppTheme.errorColor),
          );
        },
        (withdrawal) {
          ref.read(walletProvider.notifier).fetchBalance();
          _showCodeDialog(
            withdrawal.code,
            amount,
            region,
            township,
          );
        },
      );
    }
  }

  void _showCodeDialog(
      String code, double amount, String region, String township) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdrawal Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give this code to your selected agent. Your amount is held until the agent confirms payout.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor),
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Amount: ${amount.toStringAsFixed(2)} MMK'),
            Text('Region/State: $region'),
            Text('Township: $township'),
            Text('Agent: $_selectedAgentName'),
            const SizedBox(height: 16),
            const Text(
              'The agent will enter this code from the Agent app. Only then will the amount leave your balance and be credited to the agent.',
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Code'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentsState = ref.watch(agentsProvider);
    final regionsState = ref.watch(agentRegionsProvider);
    final townshipsState = _selectedRegion == null
        ? const AsyncValue<List<String>>.data(<String>[])
        : ref.watch(agentTownshipsProvider(_selectedRegion!));
    final walletState = ref.watch(walletProvider);
    final customerWithdrawalsState = ref.watch(customerWithdrawalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw Funds'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Region / State',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    regionsState.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => const Text(
                        'Unable to load Myanmar regions. Please retry.',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      data: (regions) {
                        if (regions.isEmpty) {
                          return const Text(
                            'No active agent regions are available right now.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          value: _selectedRegion,
                          decoration: const InputDecoration(
                            hintText: 'Select a region or state',
                            prefixIcon: Icon(Icons.map_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: regions
                              .map(
                                (region) => DropdownMenuItem<String>(
                                  value: region,
                                  child: Text(region),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedRegion = value;
                              _selectedTownship = null;
                              _selectedAgentId = null;
                              _selectedAgentName = null;
                            });
                            ref.read(agentsProvider.notifier).clear();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Township',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _selectedRegion == null
                        ? const Text(
                            'Select a region or state first.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          )
                        : townshipsState.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) => const Text(
                              'Unable to load townships. Please retry.',
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                            data: (townships) {
                              if (townships.isEmpty) {
                                return const Text(
                                  'No active agent townships are available in this region.',
                                  style:
                                      TextStyle(color: AppTheme.textSecondary),
                                );
                              }
                              return DropdownButtonFormField<String>(
                                value: _selectedTownship,
                                decoration: const InputDecoration(
                                  hintText: 'Select a township',
                                  prefixIcon:
                                      Icon(Icons.location_city_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: townships
                                    .map(
                                      (township) => DropdownMenuItem<String>(
                                        value: township,
                                        child: Text(township),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedTownship = value;
                                    _selectedAgentId = null;
                                    _selectedAgentName = null;
                                  });
                                  ref
                                      .read(agentsProvider.notifier)
                                      .fetchAgentsForTownship(
                                        _selectedRegion!,
                                        value,
                                      );
                                },
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Agent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _selectedTownship == null
                        ? const Text(
                            'Select a township first to see available agents.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          )
                        : agentsState.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : agentsState.error != null
                                ? const Text(
                                    'Failed to load agents',
                                    style:
                                        TextStyle(color: AppTheme.errorColor),
                                  )
                                : agentsState.agents.isEmpty
                                    ? const Text(
                                        'No active agents are registered in this township.',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary),
                                      )
                                    : DropdownButtonFormField<String>(
                                        value: _selectedAgentId,
                                        decoration: const InputDecoration(
                                          hintText: 'Select an agent code',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: agentsState.agents.map((agent) {
                                          final displayCode =
                                              agent.customCode.isEmpty
                                                  ? 'Auto-generated'
                                                  : agent.customCode;
                                          return DropdownMenuItem(
                                            value: agent.id,
                                            child: Text(
                                                '$displayCode (${agent.fullName})'),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedAgentId = value;
                                            _selectedAgentName = agentsState
                                                .agents
                                                .firstWhere(
                                                    (a) => a.id == value)
                                                .fullName;
                                          });
                                        },
                                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    walletState.when(
                      data: (wallet) => Text(
                        'Available: ${wallet.availableBalance.toStringAsFixed(2)} MMK',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      loading: () => const Text(
                        'Checking available balance...',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      error: (_, __) => const Text(
                        'Unable to check balance. You can still retry after refreshing.',
                        style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        hintText: 'Enter amount',
                        prefixIcon: Icon(Icons.payments),
                        suffixText: 'MMK',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _accountDetailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Phone number or account details for cashout',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitWithdrawal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Withdrawal Request',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 24),
            _buildRequestHistory(customerWithdrawalsState),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestHistory(
    AsyncValue<List<CustomerWithdrawalItem>> state,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your withdrawal requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Unable to load request history.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.invalidate(customerWithdrawalsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              data: (requests) {
                if (requests.isEmpty) {
                  return const Text(
                    'No withdrawal requests yet.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(height: 20),
                  itemBuilder: (context, index) =>
                      _requestTile(requests[index]),
                );
              },
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
    final seconds = remaining.inSeconds.remainder(60);
    return hours > 0
        ? 'Expires in ${hours}h ${minutes}m'
        : 'Expires in ${minutes}m ${seconds}s';
  }

  Widget _requestTile(CustomerWithdrawalItem request) {
    final isPending = request.requestStatus == 'pending' &&
        request.transactionStatus == 'pending';
    final statusColor = switch (request.requestStatus) {
      'approved' => AppTheme.successColor,
      'rejected' => AppTheme.errorColor,
      _ => AppTheme.warningColor,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${request.amount.toStringAsFixed(2)} ${request.currency}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                request.requestStatus.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${request.region.isEmpty ? request.location : request.region} • ${request.township.isEmpty ? request.location : request.township} • ${request.agentName.isEmpty ? 'Agent selected' : request.agentName} • ${request.createdAt.toLocal().toString().substring(0, 16)}',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        if (isPending) ...[
          const SizedBox(height: 6),
          Text(
            '${request.code.isEmpty ? 'Amount held pending agent confirmation.' : 'Code: ${request.code} • Amount held pending agent confirmation.'} • ${_expiryLabel(request.expiresAt)}',
            style: const TextStyle(
              color: AppTheme.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _cancelRequest(request),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel request'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _cancelRequest(CustomerWithdrawalItem request) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel withdrawal request?'),
        content: Text(
          '${request.amount.toStringAsFixed(2)} ${request.currency} is currently held. Cancelling will release it back to your available balance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;

    final failure = await ref
        .read(withdrawalProvider.notifier)
        .cancelRequest(request.requestId);
    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    ref.invalidate(customerWithdrawalsProvider);
    ref.read(walletProvider.notifier).fetchBalance();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Withdrawal request cancelled. Funds released.')),
    );
  }
}
