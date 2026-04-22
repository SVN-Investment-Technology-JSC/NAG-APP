import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';

class VehicleService {
  final Dio dio;

  VehicleService(this.dio);

  Future<List<VehicleModel>> getVehicles() async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicles';
      final response = await dio.get(
        fullUrl,
        queryParameters: {'limit': 1000},
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => VehicleModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[VehicleService] Error: $e');
      return [];
    }
  }
}
