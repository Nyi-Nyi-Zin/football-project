import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/agent_models.dart';
import '../providers/agent_provider.dart';

class AgentSupportScreen extends ConsumerWidget {
  const AgentSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentSupportTicketsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(agentSupportTicketsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Operations support',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateTicket(context, ref),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('New request'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Create a request for payout, wallet, account, or technical help. Replies stay attached to the ticket.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: const Text('Unable to load support requests'),
                subtitle: Text('$error'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(agentSupportTicketsProvider),
                ),
              ),
            ),
            data: (tickets) {
              if (tickets.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.support_agent_outlined,
                            size: 46,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 10),
                        const Text('No support requests yet'),
                        const SizedBox(height: 4),
                        const Text(
                            'Create a request when you need operations help.'),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: tickets
                    .map((ticket) => _TicketCard(
                          ticket: ticket,
                          onTap: () => _showTicket(context, ref, ticket),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateTicket(BuildContext context, WidgetRef ref) async {
    final subject = TextEditingController();
    final category = TextEditingController(text: 'operations');
    final description = TextEditingController();
    var priority = 'normal';
    final formKey = GlobalKey<FormState>();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New support request'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: subject,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    validator: (value) =>
                        (value == null || value.trim().length < 4)
                            ? 'Enter at least 4 characters'
                            : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (value) =>
                        setState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: description,
                    maxLines: 5,
                    decoration:
                        const InputDecoration(labelText: 'Describe the issue'),
                    validator: (value) =>
                        (value == null || value.trim().length < 10)
                            ? 'Enter at least 10 characters'
                            : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  await ref.read(agentDataSourceProvider).createSupportTicket(
                        subject: subject.text,
                        category: category.text,
                        priority: priority,
                        description: description.text,
                      );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                          content: Text('Could not create request: $error')),
                    );
                  }
                }
              },
              child: const Text('Submit request'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    category.dispose();
    description.dispose();
    if (created == true) {
      ref.invalidate(agentSupportTicketsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support request created')),
        );
      }
    }
  }

  Future<void> _showTicket(
    BuildContext context,
    WidgetRef ref,
    AgentSupportTicket ticket,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TicketThread(ticket: ticket),
    );
    ref.invalidate(agentSupportTicketsProvider);
  }
}

class _TicketCard extends StatelessWidget {
  final AgentSupportTicket ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  Color _statusColor(BuildContext context) {
    switch (ticket.status) {
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(Icons.support_agent_outlined, color: color),
        ),
        title:
            Text(ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Text('${ticket.category} • ${ticket.priority} • ${ticket.status}'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _TicketThread extends ConsumerStatefulWidget {
  final AgentSupportTicket ticket;

  const _TicketThread({required this.ticket});

  @override
  ConsumerState<_TicketThread> createState() => _TicketThreadState();
}

class _TicketThreadState extends ConsumerState<_TicketThread> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(agentSupportMessagesProvider(widget.ticket.id));
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.ticket.subject,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 4),
              Text('${widget.ticket.status} • ${widget.ticket.priority}'),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: .35),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(widget.ticket.description),
                      ),
                    ),
                    messages.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) =>
                          Text('Unable to load replies: $error'),
                      data: (items) => Column(
                        children: items
                            .map((message) => Align(
                                  alignment: message.authorRole == 'agent'
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 440),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: message.authorRole == 'admin'
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(message.authorRole,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(message.body),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write a reply…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(agentDataSourceProvider).addSupportMessage(
            ticketId: widget.ticket.id,
            body: _reply.text,
          );
      _reply.clear();
      ref.invalidate(agentSupportMessagesProvider(widget.ticket.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send reply: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
