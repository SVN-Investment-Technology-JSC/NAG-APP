import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/catalog/data/models/vehicle_type_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VehicleTypeService {
  final Dio _dio;

  VehicleTypeService() : _dio = Dio() {
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

  Future<List<VehicleTypeModel>> getVehicleTypes({int page = 1, int limit = 20, String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.isNotEmpty) {
        queryParams['vehicle_type_name'] = search;
      }
      final response = await _dio.get('/vehicle-types', queryParameters: queryParams);
      final dataList = response.data['data'] as List? ?? [];
      return dataList.map((e) => VehicleTypeModel.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to load vehicle types: $e');
    }
  }

  Future<VehicleTypeModel> createVehicleType(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/vehicle-types', data: data);
      return VehicleTypeModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to create vehicle type: $e');
    }
  }

  Future<VehicleTypeModel> updateVehicleType(int id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/vehicle-types/$id', data: data);
      return VehicleTypeModel.fromJson(response.data['data'] ?? response.data);
    } catch (e) {
      throw Exception('Failed to update vehicle type: $e');
    }
  }

  Future<void> deleteVehicleType(int id) async {
    try {
      await _dio.delete('/vehicle-types/$id');
    } catch (e) {
      throw Exception('Failed to delete vehicle type: $e');
    }
  }
}
