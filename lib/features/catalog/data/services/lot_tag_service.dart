import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/lot_tag_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LotTagService {
  final Dio _dio;

  LotTagService() : _dio = Dio() {
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

  Future<List<LotTagModel>> getLotTags({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      final response = await _dio.get('/lot-tags', queryParameters: queryParams);
      // Depending on API response, it could be under 'data' or a direct list
      final data = response.data;
      List? dataList;
      if (data is Map) {
        dataList = data['data'] as List? ?? data['results'] as List? ?? data['items'] as List?;
      } else if (data is List) {
        dataList = data;
      }
      dataList ??= [];
      return dataList.map((e) => LotTagModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load lot tags: $e');
    }
  }

  Future<LotTagModel> createLotTag(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/lot-tags', data: data);
      final resData = response.data;
      return LotTagModel.fromJson(resData is Map && resData.containsKey('data') ? resData['data'] : resData);
    } catch (e) {
      throw Exception('Failed to create lot tag: $e');
    }
  }

  Future<LotTagModel> updateLotTag(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/lot-tags/$id', data: data);
      final resData = response.data;
      return LotTagModel.fromJson(resData is Map && resData.containsKey('data') ? resData['data'] : resData);
    } catch (e) {
      throw Exception('Failed to update lot tag: $e');
    }
  }

  Future<void> deleteLotTag(int id) async {
    try {
      await _dio.delete('/lot-tags/$id');
    } catch (e) {
      throw Exception('Failed to delete lot tag: $e');
    }
  }
}
