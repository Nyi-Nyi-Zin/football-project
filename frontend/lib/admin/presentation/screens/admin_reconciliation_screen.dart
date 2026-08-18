import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_provider.dart';

class AdminReconciliationScreen extends ConsumerWidget {
  const AdminReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminReconciliationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet reconciliation'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminReconciliationProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load reconciliation: $error')),
        data: (report) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminReconciliationProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: report.discrepancyUsers == 0
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.orange.withValues(alpha: 0.10),
                child: ListTile(
                  leading: Icon(
                    report.discrepancyUsers == 0
                        ? Icons.verified_outlined
                        : Icons.warning_amber_outlined,
                    color: report.discrepancyUsers == 0
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text(
                    report.discrepancyUsers == 0
                        ? 'All wallets reconcile'
                        : '${report.discrepancyUsers} wallet discrepancies require review',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Generated ${report.generatedAt.toLocal()}'),
                ),
              ),
              const SizedBox(height: 12),
              _ReportGrid(
                items: [
                  (
                    'Reconciled users',
                    '${report.reconciledUsers}',
                    Colors.green
                  ),
                  (
                    'Discrepancies',
                    '${report.discrepancyUsers}',
                    Colors.orange
                  ),
                  (
                    'Transactions',
                    '${report.totalTransactions}',
                    Colors.deepPurple
                  ),
                  (
                    'Pending withdrawals',
                    '${report.pendingWithdrawals}',
                    Colors.red
                  ),
                  (
                    'Deposits',
                    report.totalDeposits.toStringAsFixed(2),
                    Colors.blue
                  ),
                  (
                    'Withdrawals',
                    report.totalWithdrawals.toStringAsFixed(2),
                    Colors.indigo
                  ),
                  (
                    'Net cash flow',
                    report.netCashFlow.toStringAsFixed(2),
                    Colors.teal
                  ),
                  (
                    'Ledger change',
                    report.totalLedgerChange.toStringAsFixed(2),
                    Colors.brown
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportGrid extends StatelessWidget {
  final List<(String, String, Color)> items;

  const _ReportGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 105,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        final item = items[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, color: item.$3),
                const SizedBox(height: 6),
                Text(item.$1, style: Theme.of(context).textTheme.bodySmall),
                Text(item.$2,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        );
      },
    );
  }
}
