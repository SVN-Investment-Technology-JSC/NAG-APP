import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/work_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkService {
  final Dio _dio;

  WorkService() : _dio = Dio() {
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

  Future<List<WorkModel>> getWorks({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['work_name'] = search;
      }
      final response = await _dio.get('/works', queryParameters: queryParams);
      final dataList = response.data['data'] as List? ?? [];
      return dataList.map((e) => WorkModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load works: $e');
    }
  }

  Future<WorkModel> createWork(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/works', data: data);
      return WorkModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create work: $e');
    }
  }

  Future<WorkModel> updateWork(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/works/$id', data: data);
      return WorkModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update work: $e');
    }
  }

  Future<void> deleteWork(int id) async {
    try {
      await _dio.delete('/works/$id');
    } catch (e) {
      throw Exception('Failed to delete work: $e');
    }
  }
}
