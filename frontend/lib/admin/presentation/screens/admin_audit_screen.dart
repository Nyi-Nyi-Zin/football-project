import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/admin_models.dart';
import '../providers/admin_provider.dart';

class AdminAuditScreen extends ConsumerStatefulWidget {
  const AdminAuditScreen({super.key});

  @override
  ConsumerState<AdminAuditScreen> createState() => _AdminAuditScreenState();
}

class _AdminAuditScreenState extends ConsumerState<AdminAuditScreen> {
  String _action = '';
  String _resourceType = '';
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final query = AuditQuery(
      action: _action,
      resourceType: _resourceType,
      page: _page,
    );
    final auditState = ref.watch(adminAuditLogsProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminAuditLogsProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            _AuditFilters(
              action: _action,
              resourceType: _resourceType,
              onActionChanged: (value) => setState(() {
                _action = value ?? '';
                _page = 1;
              }),
              onResourceChanged: (value) => setState(() {
                _resourceType = value ?? '';
                _page = 1;
              }),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: auditState.when(
                loading: () => const _AuditSkeletonList(),
                error: (error, _) => _AuditError(
                  onRetry: () => ref.invalidate(adminAuditLogsProvider(query)),
                ),
                data: (response) {
                  if (response.logs.isEmpty) {
                    return const _AuditEmpty();
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(adminAuditLogsProvider(query));
                            await ref
                                .read(adminAuditLogsProvider(query).future);
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: response.logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) =>
                                _AuditCard(log: response.logs[index]),
                          ),
                        ),
                      ),
                      _PaginationFooter(
                        page: response.page,
                        hasNext:
                            response.page * response.limit < response.total,
                        onPrevious:
                            _page > 1 ? () => setState(() => _page--) : null,
                        onNext: response.page * response.limit < response.total
                            ? () => setState(() => _page++)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditFilters extends StatelessWidget {
  final String action;
  final String resourceType;
  final ValueChanged<String?> onActionChanged;
  final ValueChanged<String?> onResourceChanged;

  const _AuditFilters({
    required this.action,
    required this.resourceType,
    required this.onActionChanged,
    required this.onResourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: action,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Action',
              prefixIcon: Icon(Icons.flash_on_outlined),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All actions')),
              DropdownMenuItem(
                value: 'wallet.balance_adjusted',
                child: Text('Wallet adjustment'),
              ),
            ],
            onChanged: onActionChanged,
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            value: resourceType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Resource',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('All resources')),
              DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
              DropdownMenuItem(value: 'withdrawal', child: Text('Withdrawal')),
              DropdownMenuItem(value: 'user', child: Text('User')),
            ],
            onChanged: onResourceChanged,
          ),
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AdminAuditLog log;

  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy, HH:mm').format(log.createdAt.toLocal());
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.action.replaceAll('.', ' '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  date,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Resource: ${log.resourceType}'),
            if (log.resourceId.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText('ID: ${log.resourceId}'),
            ],
            const SizedBox(height: 4),
            SelectableText('Admin: ${log.actorId}'),
          ],
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  final int page;
  final bool hasNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationFooter({
    required this.page,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $page'),
        IconButton(
          tooltip: 'Next page',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _AuditSkeletonList extends StatelessWidget {
  const _AuditSkeletonList();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 16, width: 210, color: color),
              const SizedBox(height: 10),
              Container(height: 12, width: 150, color: color),
              const SizedBox(height: 8),
              Container(height: 12, width: double.infinity, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditEmpty extends StatelessWidget {
  const _AuditEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.fact_check_outlined, size: 56),
        SizedBox(height: 12),
        Center(child: Text('No audit activity yet')),
      ],
    );
  }
}

class _AuditError extends StatelessWidget {
  final VoidCallback onRetry;

  const _AuditError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52),
            const SizedBox(height: 12),
            const Text(
              'Audit history is unavailable',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
