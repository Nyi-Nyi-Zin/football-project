import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../data/agent_models.dart';
import '../../data/agent_remote_datasource.dart';

final agentDataSourceProvider = Provider<AgentRemoteDataSource>((ref) {
  return AgentRemoteDataSource(ref.read(dioClientProvider));
});

final agentWithdrawStatusProvider = StateProvider<String>((_) => 'pending');

final agentWithdrawalsProvider =
    FutureProvider.autoDispose<List<AgentWithdrawalItem>>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final status = ref.watch(agentWithdrawStatusProvider);
  return ds.getAssignedWithdrawals(status: status);
});

final agentDashboardProvider =
    FutureProvider.autoDispose<AgentDashboardSummary>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  return ds.getDashboardSummary();
});

final agentEarningsDaysProvider = StateProvider<int>((_) => 30);

final agentEarningsProvider =
    FutureProvider.autoDispose<AgentEarningsSummary>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final days = ref.watch(agentEarningsDaysProvider);
  return ds.getEarnings(days: days);
});

final agentCustomerQueryProvider = StateProvider<String>((_) => '');

final agentCustomersProvider =
    FutureProvider.autoDispose<List<AgentCustomerSummary>>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final query = ref.watch(agentCustomerQueryProvider);
  return ds.getCustomers(query: query);
});

final agentSupportTicketsProvider =
    FutureProvider.autoDispose<List<AgentSupportTicket>>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  return ds.getSupportTickets();
});

final agentSupportMessagesProvider = FutureProvider.autoDispose
    .family<List<AgentSupportMessage>, String>((ref, ticketId) async {
  final ds = ref.read(agentDataSourceProvider);
  return ds.getSupportMessages(ticketId);
});
