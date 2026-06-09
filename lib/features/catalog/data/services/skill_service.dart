import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/skill_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SkillService {
  final Dio _dio;

  SkillService() : _dio = Dio() {
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

  Future<List<SkillModel>> getSkills({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['skill_name'] = search;
      }
      final response = await _dio.get('/skills', queryParameters: queryParams);
      final dataList = response.data['data'] as List? ?? [];
      return dataList.map((e) => SkillModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load skills: $e');
    }
  }

  Future<SkillModel> createSkill(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/skills', data: data);
      return SkillModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create skill: $e');
    }
  }

  Future<SkillModel> updateSkill(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/skills/$id', data: data);
      return SkillModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update skill: $e');
    }
  }

  Future<void> deleteSkill(int id) async {
    try {
      await _dio.delete('/skills/$id');
    } catch (e) {
      throw Exception('Failed to delete skill: $e');
    }
  }
}
