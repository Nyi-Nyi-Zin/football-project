import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/admin_provider.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _queryCtrl = TextEditingController();
  String _status = '';
  int _page = 1;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final asyncUsers = ref.watch(
      usersProvider(
        UserQuery(
          query: _queryCtrl.text,
          status: _status,
          page: _page,
        ),
      ),
    );
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 420,
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search by user id / email / username',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() => _page = 1),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Status')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  ],
                  onChanged: (v) => setState(() {
                    _status = v ?? '';
                    _page = 1;
                  }),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _page = 1),
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: asyncUsers.when(
                data: (res) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${res.stats.totalUsers} | Active: ${res.stats.activeUsers} | Suspended: ${res.stats.suspendedUsers}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('User ID')),
                              DataColumn(label: Text('Username')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Balance')),
                              DataColumn(label: Text('Registered')),
                              DataColumn(label: Text('Actions')),
                            ],
                            rows: res.users
                                .map(
                                  (u) => DataRow(cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: SelectableText(u.id),
                                      ),
                                    ),
                                    DataCell(Text(u.username)),
                                    DataCell(Text(u.email)),
                                    DataCell(Text(u.role)),
                                    DataCell(Text(u.status)),
                                    DataCell(Text(u.balance.toStringAsFixed(2))),
                                    DataCell(Text(dateFmt.format(u.createdAt))),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => context.go('/users/${u.id}'),
                                        child: const Text('Details'),
                                      ),
                                    ),
                                  ]),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                error: (e, _) => Center(child: Text('Failed to load users: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
