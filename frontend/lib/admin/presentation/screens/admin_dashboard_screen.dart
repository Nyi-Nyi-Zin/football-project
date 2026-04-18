import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/admin_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financialAsync = ref.watch(financialSummaryProvider);
    final usersAsync = ref.watch(usersProvider(const UserQuery(limit: 1)));
    final currency = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: financialAsync.when(
          data: (financial) {
            final usersStats = usersAsync.valueOrNull?.stats;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _KpiCard(
                      title: 'Total Users',
                      value: '${usersStats?.totalUsers ?? 0}',
                    ),
                    _KpiCard(
                      title: 'Active Users',
                      value: '${usersStats?.activeUsers ?? 0}',
                    ),
                    _KpiCard(
                      title: 'Total Deposits',
                      value: currency.format(financial.totalDeposits),
                    ),
                    _KpiCard(
                      title: 'Total Withdrawals',
                      value: currency.format(financial.totalWithdrawals),
                    ),
                    _KpiCard(
                      title: 'Pending Withdrawals',
                      value: '${financial.pendingWithdrawals}',
                    ),
                    const _KpiCard(
                      title: 'System Health',
                      value: 'Healthy',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Financial Overview',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: BarChart(
                              BarChartData(
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: false),
                                barGroups: [
                                  BarChartGroupData(x: 0, barRods: [
                                    BarChartRodData(
                                      toY: financial.totalDeposits,
                                      width: 28,
                                      color: Colors.green,
                                    ),
                                  ]),
                                  BarChartGroupData(x: 1, barRods: [
                                    BarChartRodData(
                                      toY: financial.totalWithdrawals,
                                      width: 28,
                                      color: Colors.orange,
                                    ),
                                  ]),
                                  BarChartGroupData(x: 2, barRods: [
                                    BarChartRodData(
                                      toY: financial.pendingWithdrawals
                                          .toDouble(),
                                      width: 28,
                                      color: Colors.redAccent,
                                    ),
                                  ]),
                                ],
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, _) {
                                        const labels = [
                                          'Deposits',
                                          'Withdrawals',
                                          'Pending'
                                        ];
                                        final i = value.toInt();
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                              i >= 0 && i < labels.length
                                                  ? labels[i]
                                                  : ''),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (e, _) => Center(child: Text('Failed to load dashboard: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;

  const _KpiCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
