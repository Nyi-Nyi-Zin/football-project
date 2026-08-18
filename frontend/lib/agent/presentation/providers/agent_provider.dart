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

final agentCustomerQueryProvider = StateProvider<String>((_) => '');

final agentCustomersProvider =
    FutureProvider.autoDispose<List<AgentCustomerSummary>>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final query = ref.watch(agentCustomerQueryProvider);
  return ds.getCustomers(query: query);
});
