import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../data/agent_models.dart';
import '../../data/agent_remote_datasource.dart';

final agentDataSourceProvider = Provider<AgentRemoteDataSource>((ref) {
  return AgentRemoteDataSource(ref.read(dioClientProvider));
});

final agentWithdrawStatusProvider = StateProvider<String>((_) => 'pending');

final agentWithdrawalsProvider = FutureProvider.autoDispose<List<AgentWithdrawalItem>>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final status = ref.watch(agentWithdrawStatusProvider);
  return ds.getAssignedWithdrawals(status: status);
});
