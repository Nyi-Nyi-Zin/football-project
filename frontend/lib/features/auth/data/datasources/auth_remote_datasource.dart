import '../../../../core/network/dio_client.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/nrc_model.dart';

class AuthRemoteDataSource {
  final DioClient _client;

  AuthRemoteDataSource(this._client);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
      options: Options(
        connectTimeout: AppConstants.authRequestTimeout,
        receiveTimeout: AppConstants.authRequestTimeout,
        sendTimeout: AppConstants.authRequestTimeout,
      ),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final response = await _client.dio.post(
      '/auth/register',
      data: {
        'email': email,
        'username': username,
        'password': password,
        'full_name': fullName,
        if (phone != null) 'phone': phone,
      },
      options: Options(
        connectTimeout: AppConstants.authRequestTimeout,
        receiveTimeout: AppConstants.authRequestTimeout,
        sendTimeout: AppConstants.authRequestTimeout,
      ),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<UserModel> getProfile() async {
    final response = await _client.dio.get('/users/me');
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile({
    String? fullName,
    String? phone,
    String? nrc,
    String? nrcRegion,
    String? nrcTownship,
    String? nrcType,
    String? nrcNumber,
    int? nrcRegionId,
    int? nrcTownshipId,
    int? nrcTypeId,
    String? gmail,
    String? location,
    String? region,
    String? township,
    String? customCode,
  }) async {
    final response = await _client.dio.patch('/users/me', data: {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (nrc != null) 'nrc': nrc,
      if (nrcRegion != null) 'nrc_region': nrcRegion,
      if (nrcTownship != null) 'nrc_township': nrcTownship,
      if (nrcType != null) 'nrc_type': nrcType,
      if (nrcNumber != null) 'nrc_number': nrcNumber,
      if (nrcRegionId != null) 'nrc_region_id': nrcRegionId,
      if (nrcTownshipId != null) 'nrc_township_id': nrcTownshipId,
      if (nrcTypeId != null) 'nrc_type_id': nrcTypeId,
      if (gmail != null) 'gmail': gmail,
      if (location != null) 'location': location,
      if (region != null) 'region': region,
      if (township != null) 'township': township,
      if (customCode != null) 'custom_code': customCode,
    });
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.dio.patch('/users/me/password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<List<NRCCode>> getNRCCodes() async {
    final response = await _client.dio.get('/nrc/codes');
    final data = response.data['data'] as List;
    return data.map((json) => NRCCode.fromJson(json)).toList();
  }

  Future<List<NRCTownship>> getNRCTownships(int codeId) async {
    final response = await _client.dio.get('/nrc/townships/$codeId');
    final data = response.data['data'] as List;
    return data.map((json) => NRCTownship.fromJson(json)).toList();
  }
}
