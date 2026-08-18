import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_models.dart';
import '../../data/admin_ops_models.dart';
import '../../data/admin_remote_datasource.dart';

final adminRefreshTickProvider = StreamProvider<int>((ref) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 10));
    tick++;
    yield tick;
  }
});

final financialSummaryProvider =
    FutureProvider<AdminFinancialSummary>((ref) async {
  return ref.read(adminDatasourceProvider).getFinancialSummary();
});

final usersProvider = FutureProvider.family<PaginatedUsersResponse, UserQuery>(
    (ref, query) async {
  return ref.read(adminDatasourceProvider).getUsers(
        query: query.query,
        status: query.status,
        page: query.page,
        limit: query.limit,
      );
});

final userDetailProvider =
    FutureProvider.family<AdminUser, String>((ref, userId) async {
  return ref.read(adminDatasourceProvider).getUserDetail(userId);
});

final transactionsProvider =
    FutureProvider.family<PaginatedTransactionsResponse, TxQuery>(
        (ref, query) async {
  return ref.read(adminDatasourceProvider).getTransactions(
        userId: query.userId,
        type: query.type,
        status: query.status,
        page: query.page,
        limit: query.limit,
      );
});

final withdrawalsProvider =
    FutureProvider.family<PaginatedTransactionsResponse, WithdrawalQuery>(
        (ref, query) async {
  return ref.read(adminDatasourceProvider).getWithdrawals(
        status: query.status,
        page: query.page,
        limit: query.limit,
      );
});

final adminSupportTicketsProvider =
    FutureProvider<AdminSupportTicketsResponse>((ref) async {
  return ref.read(adminDatasourceProvider).getSupportTickets();
});

final adminReconciliationProvider =
    FutureProvider<AdminReconciliationSummary>((ref) async {
  return ref.read(adminDatasourceProvider).getWalletReconciliation();
});

final adminCommissionRuleProvider =
    FutureProvider.family<AdminAgentCommissionRule, String>(
        (ref, agentId) async {
  return ref.read(adminDatasourceProvider).getAgentCommissionRule(agentId);
});

@immutable
class UserQuery {
  final String query;
  final String status;
  final int page;
  final int limit;

  const UserQuery({
    this.query = '',
    this.status = '',
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserQuery &&
        other.query == query &&
        other.status == status &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(query, status, page, limit);
}

@immutable
class TxQuery {
  final String userId;
  final String type;
  final String status;
  final int page;
  final int limit;

  const TxQuery({
    this.userId = '',
    this.type = '',
    this.status = '',
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TxQuery &&
        other.userId == userId &&
        other.type == type &&
        other.status == status &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(userId, type, status, page, limit);
}

@immutable
class WithdrawalQuery {
  final String status;
  final int page;
  final int limit;

  const WithdrawalQuery({
    this.status = '',
    this.page = 1,
    this.limit = 20,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WithdrawalQuery &&
        other.status == status &&
        other.page == page &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(status, page, limit);
}
