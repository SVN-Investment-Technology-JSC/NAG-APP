import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vehicle_management/core/network/app_endpoints.dart';
import 'package:vehicle_management/features/stations/data/models/station_model.dart';

class StationService {
  final Dio dio;

  StationService(this.dio);

  Future<List<Station>> getStations() async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}stations';
      final response = await dio.get(
        fullUrl,
        queryParameters: {'limit': 1000},
      );

      if (response.statusCode == 200 && response.data['data'] != null) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => Station.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[StationService] Error: $e');
      return [];
    }
  }
}
