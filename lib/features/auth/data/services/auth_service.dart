import 'package:dio/dio.dart';
import 'package:nguyenanh/features/auth/data/models/login_response_model.dart';

class AuthService {
  final Dio dio;

  AuthService(this.dio);

  Future<LoginResponseModel> login({
    required String username,
    required String password,
  }) async {
    final response = await dio.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );

    final data = response.data;

    if (data['statusCode'] != 200) {
      throw Exception('Login failed');
    }

    return LoginResponseModel.fromJson(data);
  }

  Future<LoginResponseModel> refresh() async {
    final response = await dio.get('/auth/refresh');
    return LoginResponseModel.fromJson(response.data);
  }
}
