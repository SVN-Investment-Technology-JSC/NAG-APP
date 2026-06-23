import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/models/end_of_day_model.dart';

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

  Future<EndOfDayStatusResponse?> getEndOfDayStatus(String? date) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicles/end-of-day-status';
      final response = await dio.get(
        fullUrl,
        queryParameters: date != null ? {'date': date} : null,
      );

      if (response.statusCode == 200) {
        final raw = response.data['data'] ?? response.data;
        return EndOfDayStatusResponse.fromJson(raw);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleService] getEndOfDayStatus Error: $e');
      return null;
    }
  }

  Future<bool> updateVehicleStatus(int vehicleId, String status) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicles/$vehicleId';
      final response = await dio.put(
        fullUrl,
        data: {'vehicle_status': status},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[VehicleService] updateVehicleStatus Error: $e');
      return false;
    }
  }
}
