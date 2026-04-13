import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final DioClient _client;

  AuthRemoteDataSource(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'email': email,
      'username': username,
      'password': password,
      'full_name': fullName,
      if (phone != null) 'phone': phone,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<UserModel> getProfile() async {
    final response = await _client.dio.get('/users/me');
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile({String? fullName, String? phone}) async {
    final response = await _client.dio.patch('/users/me', data: {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
    });
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
