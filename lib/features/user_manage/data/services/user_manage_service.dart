import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/user_manage/data/models/user_manage_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserManageService {
  final Dio _dio;

  UserManageService() : _dio = Dio() {
    _dio.options.baseUrl = AppEndpoints.apiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>> getUsers({int page = 1, int limit = 10, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['user_full_name'] = search;
      }

      final response = await _dio.get('/users', queryParameters: queryParams);
      
      final dataList = response.data['data'] as List? ?? [];
      final users = dataList.map((e) => UserManageModel.fromJson(e)).toList();
      final total = response.data['total'] ?? response.data['meta']?['total'] ?? 0;

      return {
        'users': users,
        'total': total,
      };
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  Future<UserManageModel> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await _dio.post('/users', data: userData);
      return UserManageModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<UserManageModel> updateUser(int userId, Map<String, dynamic> userData) async {
    try {
      final response = await _dio.put('/users/$userId', data: userData);
      return UserManageModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _dio.delete('/users/$userId');
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<Map<String, List<String>>> getPermissions() async {
    try {
      final response = await _dio.get('/permissions');
      final Map<String, dynamic> rawData = response.data['data'] ?? response.data;
      final Map<String, List<String>> permissions = {};
      
      rawData.forEach((key, value) {
        if (value is List) {
          permissions[key] = value.map((e) => e.toString()).toList();
        }
      });
      return permissions;
    } catch (e) {
      throw Exception('Failed to load permissions: $e');
    }
  }

  Future<void> updatePermissions(Map<String, List<String>> permissions) async {
    try {
      await _dio.put('/permissions', data: permissions);
    } catch (e) {
      throw Exception('Failed to update permissions: $e');
    }
  }
}
