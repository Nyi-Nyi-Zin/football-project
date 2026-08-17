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
  String? _selectedLocation;
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
    final location = _selectedLocation?.trim() ?? '';
    final accountDetails = _accountDetailsController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
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
          location: location,
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
            location,
          );
        },
      );
    }
  }

  void _showCodeDialog(String code, double amount, String location) {
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
            Text('City: $location'),
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
    final locationsState = ref.watch(agentLocationsProvider);
    final walletState = ref.watch(walletProvider);

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
                      'City',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    locationsState.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => const Text(
                        'Unable to load cities. Please refresh and try again.',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      data: (locations) {
                        if (locations.isEmpty) {
                          return const Text(
                            'No active agent cities are available right now.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          );
                        }
                        return DropdownButtonFormField<String>(
                          initialValue: _selectedLocation,
                          decoration: const InputDecoration(
                            hintText: 'Select a city',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: locations
                              .map(
                                (location) => DropdownMenuItem<String>(
                                  value: location,
                                  child: Text(location),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedLocation = value;
                              _selectedAgentId = null;
                              _selectedAgentName = null;
                            });
                            ref
                                .read(agentsProvider.notifier)
                                .fetchAgents(value);
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
                    _selectedLocation == null
                        ? const Text(
                            'Select a city first to see available agents.',
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
                                        'No agents available for this location',
                                        style: TextStyle(
                                            color: AppTheme.textSecondary),
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue: _selectedAgentId,
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
          ],
        ),
      ),
    );
  }
}
