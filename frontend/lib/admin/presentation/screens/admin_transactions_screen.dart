import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_remote_datasource.dart';
import '../providers/admin_provider.dart';

class AdminTransactionsScreen extends ConsumerStatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  ConsumerState<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends ConsumerState<AdminTransactionsScreen> {
  final _userIdCtrl = TextEditingController();
  String _type = '';
  String _status = '';
  int _page = 1;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final query = TxQuery(
      userId: _userIdCtrl.text,
      type: _type,
      status: _status,
      page: _page,
      limit: 20,
    );
    final asyncTx = ref.watch(transactionsProvider(query));
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Monitoring'),
        actions: [
          IconButton(
            onPressed: () => _exportCsv(query),
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 260,
                  child: TextField(
                    controller: _userIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Filter by user ID',
                    ),
                    onSubmitted: (_) => setState(() => _page = 1),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _type,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Types')),
                    DropdownMenuItem(value: 'deposit', child: Text('Deposit')),
                    DropdownMenuItem(value: 'withdraw', child: Text('Withdraw')),
                    DropdownMenuItem(value: 'refund', child: Text('Refund')),
                  ],
                  onChanged: (v) => setState(() {
                    _type = v ?? '';
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Status')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (v) => setState(() {
                    _status = v ?? '';
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => setState(() => _page = 1),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: asyncTx.when(
                data: (res) {
                  return Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Transaction ID')),
                              DataColumn(label: Text('User ID')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Amount')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Description')),
                              DataColumn(label: Text('Timestamp')),
                            ],
                            rows: res.transactions
                                .map(
                                  (tx) => DataRow(cells: [
                                    DataCell(SizedBox(width: 170, child: Text(tx.id))),
                                    DataCell(
                                      SizedBox(
                                        width: 170,
                                        child: SelectableText(tx.userId),
                                      ),
                                    ),
                                    DataCell(Text(tx.type)),
                                    DataCell(Text('${tx.amount.toStringAsFixed(2)} ${tx.currency}')),
                                    DataCell(Text(tx.status)),
                                    DataCell(SizedBox(width: 260, child: Text(tx.description))),
                                    DataCell(Text(dateFmt.format(tx.createdAt))),
                                  ]),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: _page > 1 ? () => setState(() => _page--) : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page $_page / ${res.lastPage}'),
                          IconButton(
                            onPressed: _page < res.lastPage ? () => setState(() => _page++) : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                error: (e, _) => Center(child: Text('Failed to load transactions: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(TxQuery query) async {
    try {
      final csv = await ref.read(adminDatasourceProvider).exportTransactionsCsv(
            userId: query.userId,
            type: query.type,
            status: query.status,
          );
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }
}
