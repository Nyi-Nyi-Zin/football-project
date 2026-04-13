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

  Future<bool> deposit(double amount) async {
    try {
      await _dataSource.deposit(amount);
      await fetchBalance();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> withdraw(double amount) async {
    try {
      await _dataSource.withdraw(amount);
      await fetchBalance();
      return true;
    } catch (e) {
      return false;
    }
  }
}

final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final ds = ref.read(paymentDatasourceProvider);
  final txs = await ds.getTransactions();
  return txs.map((t) => t.toEntity()).toList();
});
