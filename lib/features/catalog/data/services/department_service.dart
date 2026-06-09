import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/department_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DepartmentService {
  final Dio _dio;

  DepartmentService() : _dio = Dio() {
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

  Future<List<DepartmentModel>> getDepartments({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['department_name'] = search;
      }
      final response = await _dio.get('/departments', queryParameters: queryParams);
      final dataList = response.data['data'] as List? ?? [];
      return dataList.map((e) => DepartmentModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load departments: $e');
    }
  }

  Future<DepartmentModel> createDepartment(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/departments', data: data);
      return DepartmentModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create department: $e');
    }
  }

  Future<DepartmentModel> updateDepartment(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/departments/$id', data: data);
      return DepartmentModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update department: $e');
    }
  }

  Future<void> deleteDepartment(int id) async {
    try {
      await _dio.delete('/departments/$id');
    } catch (e) {
      throw Exception('Failed to delete department: $e');
    }
  }
}
