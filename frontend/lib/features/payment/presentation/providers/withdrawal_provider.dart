import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/dio_client.dart';

// Agent Info Entity
class AgentInfo {
  final String id;
  final String username;
  final String fullName;
  final String region;
  final String township;
  final String location;
  final String customCode;

  AgentInfo({
    required this.id,
    required this.username,
    required this.fullName,
    this.region = '',
    this.township = '',
    required this.location,
    this.customCode = '',
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as String,
      username: json['username'] as String,
      fullName:
          json['full_name'] as String? ?? json['fullName'] as String? ?? '',
      region: json['region'] as String? ?? '',
      township: json['township'] as String? ?? '',
      location: json['location'] as String? ?? '',
      customCode: json['custom_code'] as String? ?? '',
    );
  }
}

// Withdrawal Request Entity
class CustomerWithdrawalItem {
  final String requestId;
  final String transactionId;
  final String agentId;
  final String requestStatus;
  final String transactionStatus;
  final String region;
  final String township;
  final String location;
  final String code;
  final double amount;
  final String currency;
  final DateTime createdAt;

  const CustomerWithdrawalItem({
    required this.requestId,
    required this.transactionId,
    required this.agentId,
    required this.requestStatus,
    required this.transactionStatus,
    this.region = '',
    this.township = '',
    required this.location,
    required this.code,
    required this.amount,
    required this.currency,
    required this.createdAt,
  });

  factory CustomerWithdrawalItem.fromJson(Map<String, dynamic> json) {
    final request = json['request'] as Map<String, dynamic>? ?? const {};
    final transaction =
        json['transaction'] as Map<String, dynamic>? ?? const {};
    return CustomerWithdrawalItem(
      requestId: request['id'] as String? ?? '',
      transactionId: transaction['id'] as String? ?? '',
      agentId: request['agent_id'] as String? ?? '',
      requestStatus: request['status'] as String? ?? 'pending',
      transactionStatus: transaction['status'] as String? ?? 'pending',
      region: request['region'] as String? ?? '',
      township: request['township'] as String? ?? '',
      location: request['location'] as String? ?? '',
      code: request['code'] as String? ?? '',
      amount: (transaction['amount'] as num?)?.toDouble() ?? 0,
      currency: transaction['currency'] as String? ?? 'MMK',
      createdAt: DateTime.tryParse(
            transaction['created_at'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

class WithdrawalRequest {
  final String id;
  final String transactionId;
  final String customerId;
  final String agentId;
  final String status;
  final String location;
  final String code;
  final DateTime? approvedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;

  WithdrawalRequest({
    required this.id,
    required this.transactionId,
    required this.customerId,
    required this.agentId,
    required this.status,
    required this.location,
    required this.code,
    this.approvedAt,
    this.cancelledAt,
    required this.createdAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequest(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      customerId: json['customer_id'] as String,
      agentId: json['agent_id'] as String,
      status: json['status'] as String,
      location: json['location'] as String,
      code: json['code'] as String,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// State classes
class AgentsState {
  final List<AgentInfo> agents;
  final bool isLoading;
  final Failure? error;

  AgentsState({
    this.agents = const [],
    this.isLoading = false,
    this.error,
  });

  AgentsState copyWith({
    List<AgentInfo>? agents,
    bool? isLoading,
    Failure? error,
  }) {
    return AgentsState(
      agents: agents ?? this.agents,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WithdrawalState {
  final WithdrawalRequest? withdrawal;
  final bool isLoading;
  final Failure? error;

  WithdrawalState({
    this.withdrawal,
    this.isLoading = false,
    this.error,
  });

  WithdrawalState copyWith({
    WithdrawalRequest? withdrawal,
    bool? isLoading,
    Failure? error,
  }) {
    return WithdrawalState(
      withdrawal: withdrawal ?? this.withdrawal,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Notifiers
class AgentsNotifier extends StateNotifier<AgentsState> {
  final DioClient _dioClient;

  AgentsNotifier(this._dioClient) : super(AgentsState());

  void clear() {
    state = AgentsState();
  }

  Future<void> fetchAgents(String location) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final encodedLocation = Uri.encodeComponent(location.trim());
      final response =
          await _dioClient.dio.get('/withdrawals/agents/$encodedLocation');
      final List<dynamic> data = response.data['data'] as List<dynamic>;
      final agents = data
          .map((json) => AgentInfo.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(agents: agents, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ServerFailure(message: e.toString()),
      );
    }
  }

  Future<void> fetchAgentsForTownship(String region, String township) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dioClient.dio.get('/withdrawals/agents',
          queryParameters: {'region': region, 'township': township});
      final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
      final agents = data
          .map((json) => AgentInfo.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(agents: agents, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ServerFailure(message: e.toString()),
      );
    }
  }
}

class WithdrawalNotifier extends StateNotifier<WithdrawalState> {
  final DioClient _dioClient;

  WithdrawalNotifier(this._dioClient) : super(WithdrawalState());

  Future<Either<Failure, WithdrawalRequest>> createWithdrawal({
    required double amount,
    required String region,
    required String township,
    required String location,
    required String agentId,
    required String accountDetails,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dioClient.dio.post('/withdrawals', data: {
        'amount': amount,
        'region': region,
        'township': township,
        'location': location,
        'agent_id': agentId,
        'account_details': accountDetails,
      });
      final withdrawal = WithdrawalRequest.fromJson(
          response.data['data'] as Map<String, dynamic>);
      state = state.copyWith(withdrawal: withdrawal, isLoading: false);
      return Right(withdrawal);
    } catch (e) {
      final failure = ServerFailure(message: e.toString());
      state = state.copyWith(isLoading: false, error: failure);
      return Left(failure);
    }
  }

  Future<Either<Failure, WithdrawalRequest>> approveWithdrawal(
      String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dioClient.dio
          .post('/withdrawals/approve', data: {'code': code});
      final withdrawal = WithdrawalRequest.fromJson(
          response.data['data'] as Map<String, dynamic>);
      state = state.copyWith(withdrawal: withdrawal, isLoading: false);
      return Right(withdrawal);
    } catch (e) {
      final failure = ServerFailure(message: e.toString());
      state = state.copyWith(isLoading: false, error: failure);
      return Left(failure);
    }
  }

  Future<Failure?> cancelRequest(String requestId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dioClient.dio.delete('/withdrawals/$requestId');
      state = state.copyWith(isLoading: false);
      return null;
    } catch (e) {
      final failure = ServerFailure(message: e.toString());
      state = state.copyWith(isLoading: false, error: failure);
      return failure;
    }
  }

  Future<Either<Failure, void>> cancelWithdrawal(String requestId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _dioClient.dio.delete('/withdrawals/$requestId');
      state = state.copyWith(isLoading: false);
      return const Right(null);
    } catch (e) {
      final failure = ServerFailure(message: e.toString());
      state = state.copyWith(isLoading: false, error: failure);
      return Left(failure);
    }
  }
}

// Providers
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

final agentLocationsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final client = ref.read(dioClientProvider);
  final response = await client.dio.get('/withdrawals/locations');
  final data = response.data['data'] as List<dynamic>? ?? const [];
  return data.map((location) => location.toString()).toList();
});

final agentRegionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final client = ref.read(dioClientProvider);
  final response = await client.dio.get('/withdrawals/regions');
  final data = response.data['data'] as List<dynamic>? ?? const [];
  return data.map((region) => region.toString()).toList();
});

final agentTownshipsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, region) async {
  final client = ref.read(dioClientProvider);
  final response = await client.dio
      .get('/withdrawals/townships', queryParameters: {'region': region});
  final data = response.data['data'] as List<dynamic>? ?? const [];
  return data.map((township) => township.toString()).toList();
});

final customerWithdrawalsProvider =
    FutureProvider.autoDispose<List<CustomerWithdrawalItem>>((ref) async {
  final client = ref.read(dioClientProvider);
  final response = await client.dio.get('/withdrawals', queryParameters: {
    'page': 1,
    'limit': 20,
  });
  final data = response.data['data'] as List<dynamic>? ?? const [];
  return data
      .map((item) =>
          CustomerWithdrawalItem.fromJson(item as Map<String, dynamic>))
      .toList();
});

final agentsProvider =
    StateNotifierProvider<AgentsNotifier, AgentsState>((ref) {
  return AgentsNotifier(ref.watch(dioClientProvider));
});

final withdrawalProvider =
    StateNotifierProvider<WithdrawalNotifier, WithdrawalState>((ref) {
  return WithdrawalNotifier(ref.watch(dioClientProvider));
});
