import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/payment_model.dart';
import 'package:uuid/uuid.dart';

class PaymentRemoteDataSource {
  final DioClient _client;
  final _uuid = const Uuid();

  PaymentRemoteDataSource(this._client);

  Future<WalletModel> getBalance() async {
    final response = await _client.dio.get('/payments/balance');
    return WalletModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<TransactionModel>> getTransactions({int page = 1, int limit = 20}) async {
    final response = await _client.dio.get(
      '/payments/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as List;
    return data.map((e) => TransactionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TransactionModel> deposit(double amount) async {
    final idempotencyKey = _uuid.v4();
    final response = await _client.dio.post(
      '/payments/deposit',
      data: {'amount': amount},
      options: Options(
        headers: {'X-Idempotency-Key': idempotencyKey},
      ),
    );
    return TransactionModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<TransactionModel> withdraw(double amount) async {
    final idempotencyKey = _uuid.v4();
    final response = await _client.dio.post(
      '/payments/withdraw',
      data: {'amount': amount},
      options: Options(
        headers: {'X-Idempotency-Key': idempotencyKey},
      ),
    );
    return TransactionModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
