import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/payment_remote_datasource.dart';
import '../../domain/entities/payment_entity.dart';

final paymentDatasourceProvider = Provider<PaymentRemoteDataSource>((ref) {
  return PaymentRemoteDataSource(ref.read(dioClientProvider));
});

final walletProvider = StateNotifierProvider<WalletNotifier, AsyncValue<Wallet>>((ref) {
  return WalletNotifier(ref.read(paymentDatasourceProvider));
});

class WalletNotifier extends StateNotifier<AsyncValue<Wallet>> {
  final PaymentRemoteDataSource _dataSource;

  WalletNotifier(this._dataSource) : super(const AsyncLoading()) {
    fetchBalance();
  }

  Future<void> fetchBalance() async {
    state = const AsyncLoading();
    try {
      final w = await _dataSource.getBalance();
      state = AsyncData(w.toEntity());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<WithdrawalSubmission?> withdraw({
    required double amount,
    required String accountDetails,
  }) async {
    try {
      final submission = await _dataSource.withdraw(
        amount: amount,
        accountDetails: accountDetails,
      );
      await fetchBalance();
      return submission.toEntity();
    } catch (_) {
      return null;
    }
  }
}

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final ds = ref.read(paymentDatasourceProvider);
  final txs = await ds.getTransactions();
  return txs.map((t) => t.toEntity()).toList();
});
