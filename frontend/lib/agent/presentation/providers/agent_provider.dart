import 'dart:async';

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

final agentReconciliationProvider =
    FutureProvider.autoDispose<AgentReconciliationReport>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final days = ref.watch(agentEarningsDaysProvider);
  return ds.getReconciliation(days: days);
});

final agentCommissionStatementProvider =
    FutureProvider.autoDispose<AgentCommissionStatement>((ref) async {
  final ds = ref.read(agentDataSourceProvider);
  final days = ref.watch(agentEarningsDaysProvider);
  return ds.getCommissionStatement(days: days);
});

final agentConnectivityProvider = StateNotifierProvider.autoDispose<
    AgentConnectivityNotifier, AgentConnectivityState>((ref) {
  return AgentConnectivityNotifier(ref.read(dioClientProvider));
});

class AgentConnectivityState {
  final bool isOnline;
  final bool isChecking;
  final DateTime? checkedAt;

  const AgentConnectivityState({
    required this.isOnline,
    required this.isChecking,
    this.checkedAt,
  });

  AgentConnectivityState copyWith({
    bool? isOnline,
    bool? isChecking,
    DateTime? checkedAt,
  }) {
    return AgentConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      isChecking: isChecking ?? this.isChecking,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }
}

class AgentConnectivityNotifier extends StateNotifier<AgentConnectivityState> {
  final DioClient _client;
  Timer? _timer;
  bool _requestInFlight = false;

  AgentConnectivityNotifier(this._client)
      : super(const AgentConnectivityState(isOnline: false, isChecking: true)) {
    checkNow();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => checkNow());
  }

  Future<void> checkNow() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    state = state.copyWith(isChecking: true);
    final online = await _client.checkHealth();
    state = AgentConnectivityState(
      isOnline: online,
      isChecking: false,
      checkedAt: DateTime.now(),
    );
    _requestInFlight = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
