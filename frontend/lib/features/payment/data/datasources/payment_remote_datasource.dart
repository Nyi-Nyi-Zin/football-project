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

  Future<List<TransactionModel>> getTransactions(
      {int page = 1, int limit = 20}) async {
    final response = await _client.dio.get(
      '/payments/transactions',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionModel> deposit({
    required double amount,
    String currency = 'MMK',
    String paymentMethod = 'manual_demo',
  }) async {
    final idempotencyKey = _uuid.v4();
    final response = await _client.dio.post(
      '/payments/deposit',
      data: {
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
        'idempotency_key': idempotencyKey,
      },
      options: Options(
        headers: {'X-Idempotency-Key': idempotencyKey},
      ),
    );
    return TransactionModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<TransactionModel> depositForCustomer({
    required String customerId,
    required double amount,
  }) async {
    final response = await _client.dio.post(
      '/agent/deposits/customer',
      data: {
        'customer_id': customerId,
        'amount': amount,
      },
    );
    return TransactionModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<WithdrawalSubmissionModel> withdraw({
    required double amount,
    required String accountDetails,
    String currency = 'USD',
    String paymentMethod = 'manual_agent',
  }) async {
    final idempotencyKey = _uuid.v4();
    final response = await _client.dio.post(
      '/payments/withdraw',
      data: {
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
        'account_details': accountDetails,
      },
      options: Options(
        headers: {'X-Idempotency-Key': idempotencyKey},
      ),
    );
    return WithdrawalSubmissionModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}
