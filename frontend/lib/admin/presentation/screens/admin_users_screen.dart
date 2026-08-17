import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/admin_provider.dart';
import '../../data/admin_remote_datasource.dart';
import '../../../features/payment/presentation/providers/withdrawal_provider.dart';

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

  Future<void> _showCreateAccountDialog() async {
    final emailCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    var role = 'user';
    var status = 'active';
    String? region;
    String? township;
    var isSaving = false;
    final regionsFuture = ref.read(agentRegionsProvider.future);

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final isAgent = role == 'agent';
            final townshipsFuture = region == null
                ? null
                : ref.read(agentTownshipsProvider(region!).future);

            Future<void> submit() async {
              if (emailCtrl.text.trim().isEmpty ||
                  usernameCtrl.text.trim().isEmpty ||
                  passwordCtrl.text.length < 8 ||
                  fullNameCtrl.text.trim().length < 2) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Complete all required fields. Password must be at least 8 characters.'),
                  ),
                );
                return;
              }
              if (isAgent && (region == null || township == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Select a region and township for the agent.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                await ref.read(adminDatasourceProvider).createUser(
                      email: emailCtrl.text,
                      username: usernameCtrl.text,
                      password: passwordCtrl.text,
                      fullName: fullNameCtrl.text,
                      phone: phoneCtrl.text,
                      role: role,
                      status: status,
                      region: isAgent ? region! : '',
                      township: isAgent ? township! : '',
                    );
                if (!context.mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() => _page = 1);
                ref.invalidate(
                  usersProvider(
                    UserQuery(
                      query: _queryCtrl.text,
                      status: _status,
                      page: _page,
                    ),
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          '${isAgent ? 'Agent' : 'User'} account created successfully.')),
                );
              } catch (error) {
                if (context.mounted) {
                  setDialogState(() => isSaving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to create account: $error')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Create account'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration:
                            const InputDecoration(labelText: 'Account type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'user', child: Text('Customer user')),
                          DropdownMenuItem(
                              value: 'agent', child: Text('Agent')),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() {
                                  role = value ?? 'user';
                                  if (role != 'agent') {
                                    region = null;
                                    township = null;
                                  }
                                }),
                      ),
                      TextField(
                          controller: fullNameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Full name')),
                      TextField(
                          controller: usernameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Username')),
                      TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress),
                      TextField(
                          controller: passwordCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                          obscureText: true),
                      TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Phone (optional)')),
                      DropdownButtonFormField<String>(
                        value: status,
                        decoration:
                            const InputDecoration(labelText: 'Initial status'),
                        items: const [
                          DropdownMenuItem(
                              value: 'active', child: Text('Active')),
                          DropdownMenuItem(
                              value: 'suspended', child: Text('Suspended')),
                          DropdownMenuItem(
                              value: 'blocked', child: Text('Blocked')),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(
                                () => status = value ?? 'active'),
                      ),
                      if (isAgent) ...[
                        FutureBuilder<List<String>>(
                          future: regionsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Unable to load agent regions.'),
                              );
                            }
                            final regions = snapshot.data ?? const <String>[];
                            return DropdownButtonFormField<String>(
                              value: regions.contains(region) ? region : null,
                              decoration: const InputDecoration(
                                  labelText: 'Region / State'),
                              items: regions
                                  .map((item) => DropdownMenuItem(
                                      value: item, child: Text(item)))
                                  .toList(),
                              onChanged: isSaving
                                  ? null
                                  : (value) => setDialogState(() {
                                        region = value;
                                        township = null;
                                      }),
                            );
                          },
                        ),
                        if (region != null)
                          FutureBuilder<List<String>>(
                            future: townshipsFuture,
                            builder: (context, snapshot) {
                              final townships =
                                  snapshot.data ?? const <String>[];
                              return DropdownButtonFormField<String>(
                                value: townships.contains(township)
                                    ? township
                                    : null,
                                decoration: const InputDecoration(
                                    labelText: 'Township'),
                                items: townships
                                    .map((item) => DropdownMenuItem(
                                        value: item, child: Text(item)))
                                    .toList(),
                                onChanged: isSaving
                                    ? null
                                    : (value) =>
                                        setDialogState(() => township = value),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create account'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      emailCtrl.dispose();
      usernameCtrl.dispose();
      passwordCtrl.dispose();
      fullNameCtrl.dispose();
      phoneCtrl.dispose();
    }
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
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            onPressed: _showCreateAccountDialog,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Create user or agent account',
          ),
        ],
      ),
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
                    DropdownMenuItem(
                        value: 'suspended', child: Text('Suspended')),
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
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: FilledButton.icon(
                    onPressed: _showCreateAccountDialog,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Create account'),
                  ),
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
                              DataColumn(label: Text('Agent Location')),
                              DataColumn(label: Text('Pending Payouts')),
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
                                    DataCell(
                                        Text(u.balance.toStringAsFixed(2))),
                                    DataCell(Text(u.role == 'agent'
                                        ? '${u.region.isEmpty ? '—' : u.region} / ${u.township.isEmpty ? '—' : u.township}'
                                        : '—')),
                                    DataCell(Text(u.role == 'agent'
                                        ? '${u.pendingWithdrawalCount}'
                                        : '—')),
                                    DataCell(Text(dateFmt.format(u.createdAt))),
                                    DataCell(
                                      TextButton(
                                        onPressed: () =>
                                            context.go('/users/${u.id}'),
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
                            onPressed: _page > 1
                                ? () => setState(() => _page--)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page $_page / ${res.lastPage}'),
                          IconButton(
                            onPressed: _page < res.lastPage
                                ? () => setState(() => _page++)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  );
                },
                error: (e, _) =>
                    Center(child: Text('Failed to load users: $e')),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
