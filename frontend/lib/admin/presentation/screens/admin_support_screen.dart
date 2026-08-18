import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_ops_models.dart';
import '../providers/admin_provider.dart';
import '../../data/admin_remote_datasource.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSupportTicketsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support triage'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(
                    value: 'in_progress', child: Text('In progress')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) =>
                  setState(() => _statusFilter = value ?? 'all'),
            ),
          ),
          IconButton(
            onPressed: () => ref.invalidate(adminSupportTicketsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load tickets: $error')),
        data: (response) {
          final tickets = _statusFilter == 'all'
              ? response.tickets
              : response.tickets
                  .where((ticket) => ticket.status == _statusFilter)
                  .toList();
          if (tickets.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminSupportTicketsProvider),
              child: ListView(children: const [
                SizedBox(height: 220),
                Center(child: Text('No tickets match this filter'))
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminSupportTicketsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _TicketCard(
                ticket: tickets[index],
                onStatusChanged: (status) =>
                    _updateStatus(tickets[index], status),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(AdminSupportTicket ticket, String status) async {
    try {
      await ref.read(adminDatasourceProvider).updateSupportTicketStatus(
            ticketId: ticket.id,
            status: status,
          );
      ref.invalidate(adminSupportTicketsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket status changed to $status')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update ticket: $error')),
        );
      }
    }
  }
}

class _TicketCard extends StatelessWidget {
  final AdminSupportTicket ticket;
  final ValueChanged<String> onStatusChanged;

  const _TicketCard({required this.ticket, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final priorityColor = switch (ticket.priority) {
      'urgent' => Colors.red,
      'high' => Colors.orange,
      'low' => Colors.blueGrey,
      _ => Colors.deepPurple,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ticket.subject,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                Chip(
                  label: Text(ticket.priority.toUpperCase()),
                  labelStyle: TextStyle(color: priorityColor, fontSize: 11),
                  side: BorderSide(color: priorityColor.withValues(alpha: 0.3)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(ticket.description,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ticket.category,
                    style: Theme.of(context).textTheme.bodySmall),
                Text('Requester ${ticket.requesterId}',
                    style: Theme.of(context).textTheme.bodySmall),
                DropdownButton<String>(
                  value: ticket.status,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                        value: 'in_progress', child: Text('In progress')),
                    DropdownMenuItem(
                        value: 'resolved', child: Text('Resolved')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (value) {
                    if (value != null && value != ticket.status) {
                      onStatusChanged(value);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
