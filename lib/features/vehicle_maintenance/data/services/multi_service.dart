import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_comment_model.dart';

class MultiService {
  final Dio dio;

  MultiService(this.dio);

  Future<Map<String, dynamic>?> getVehicleMaintenanceDiscussComments(int maintenanceId) async {
    try {
      final String multiType = 'discuss-vehicle-maintenance-$maintenanceId';
      final String fullUrl = '${AppEndpoints.apiBaseUrl}multi';
      final response = await dio.get(fullUrl, queryParameters: {
        'multi_type': multiType,
        'limit': 1,
      });

      if (response.statusCode == 200) {
        final dynamic respData = response.data['data'];
        final rawData = (respData is List) ? respData : respData?['data'];
        
        if (rawData != null && rawData is List && rawData.isNotEmpty) {
          final record = rawData.first;
          final int multiId = record['multi_id'];
          
          String? multiDataStr;
          final multiData = record['multi_data'];
          if (multiData is String) {
            multiDataStr = multiData;
          } else if (multiData is Map && multiData['data'] != null) {
            final dataField = multiData['data'];
            if (dataField is List && dataField.isNotEmpty) {
              multiDataStr = dataField.first?.toString();
            } else {
              multiDataStr = dataField.toString();
            }
          }

          List<VehicleMaintenanceComment> comments = [];
          if (multiDataStr != null && multiDataStr is String) {
            try {
              final List<dynamic> parsed = jsonDecode(multiDataStr);
              comments = parsed.map((e) => VehicleMaintenanceComment.fromJson(e)).toList();
            } catch (e) {
              debugPrint('Error parsing comments: $e');
            }
          }
          return {
            'comments': comments,
            'multiId': multiId,
          };
        }
      }
      return {
        'comments': <VehicleMaintenanceComment>[],
        'multiId': null,
      };
    } catch (e) {
      debugPrint('[MultiService] getVehicleMaintenanceDiscussComments Error: $e');
      return {
        'comments': <VehicleMaintenanceComment>[],
        'multiId': null,
      };
    }
  }

  Future<int?> saveVehicleMaintenanceDiscussComments(int maintenanceId, List<VehicleMaintenanceComment> comments, int? multiId) async {
    try {
      final payload = {
        'multi_name': 'discuss',
        'multi_type': 'discuss-vehicle-maintenance-$maintenanceId',
        'multi_description': 'Thao luan phieu bao tri #$maintenanceId',
        'multi_data': {
          'data': [jsonEncode(comments.map((e) => e.toJson()).toList())]
        },
      };

      if (multiId != null) {
        final String fullUrl = '${AppEndpoints.apiBaseUrl}multi/$multiId';
        final response = await dio.put(fullUrl, data: payload);
        if (response.statusCode == 200) {
          return multiId;
        }
      } else {
        final String fullUrl = '${AppEndpoints.apiBaseUrl}multi';
        final response = await dio.post(fullUrl, data: payload);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return response.data['data']?['multi_id'] ?? response.data['multi_id'];
        }
      }
      return null;
    } on DioException catch (e) {
      debugPrint('[MultiService] DioError: ${e.message}');
      if (e.response != null) {
        debugPrint('[MultiService] Response data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      debugPrint('[MultiService] saveVehicleMaintenanceDiscussComments Error: $e');
      rethrow;
    }
  }
}
