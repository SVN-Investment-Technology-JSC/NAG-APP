import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/user_assignment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserAssignmentService {
  final Dio _dio;

  UserAssignmentService() : _dio = Dio() {
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

  Future<List<UserAssignmentModel>> getUserAssignments({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['user_full_name'] = search;
      }
      final response = await _dio.get('/user-assignments', queryParameters: queryParams);
      final dataList = response.data['data'] as List? ?? [];
      return dataList.map((e) => UserAssignmentModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load user assignments: $e');
    }
  }

  Future<UserAssignmentModel> createUserAssignment(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/user-assignments', data: data);
      return UserAssignmentModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create user assignment: $e');
    }
  }

  Future<UserAssignmentModel> updateUserAssignment(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/user-assignments/$id', data: data);
      return UserAssignmentModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update user assignment: $e');
    }
  }

  Future<void> deleteUserAssignment(int id) async {
    try {
      await _dio.delete('/user-assignments/$id');
    } catch (e) {
      throw Exception('Failed to delete user assignment: $e');
    }
  }
}
