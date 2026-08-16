import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/withdrawal_provider.dart';

class WithdrawalScreen extends ConsumerStatefulWidget {
  const WithdrawalScreen({super.key});

  @override
  ConsumerState<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends ConsumerState<WithdrawalScreen> {
  final _amountController = TextEditingController();
  final _accountDetailsController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedAgentId;
  String? _selectedAgentName;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _accountDetailsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAgents(String location) async {
    if (location.isEmpty) return;
    await ref.read(agentsProvider.notifier).fetchAgents(location);
  }

  Future<void> _submitWithdrawal() async {
    final amount = double.tryParse(_amountController.text);
    final location = _locationController.text.trim();
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
          _showCodeDialog(withdrawal.code);
        },
      );
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdrawal Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Give this code to your selected agent:'),
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
            Text('Agent: $_selectedAgentName'),
            const SizedBox(height: 16),
            const Text(
                'The agent will enter this code to approve your withdrawal.'),
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
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your location (e.g., Yangon)',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _selectedAgentId = null;
                        _selectedAgentName = null;
                        if (value.length >= 3) {
                          _fetchAgents(value);
                        }
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
                    agentsState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : agentsState.error != null
                            ? Text(
                                'Failed to load agents',
                                style: TextStyle(color: AppTheme.errorColor),
                              )
                            : agentsState.agents.isEmpty
                                ? const Text(
                                    'No agents available for this location',
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
                                        _selectedAgentName = agentsState.agents
                                            .firstWhere((a) => a.id == value)
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
