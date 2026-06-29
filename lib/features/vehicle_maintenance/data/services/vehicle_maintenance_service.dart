import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_model.dart';
import 'package:nguyenanh/features/vehicle_maintenance/data/models/vehicle_maintenance_history_model.dart';

class VehicleMaintenanceService {
  final Dio dio;

  VehicleMaintenanceService(this.dio);

  Future<List<VehicleMaintenance>> getVehicleMaintenances({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String? sort,
    bool mine = false,
  }) async {
    try {
      final Map<String, dynamic> queryParameters = {
        'page': page,
        'limit': limit,
      };
      
      if (status != null && status != 'all') {
        queryParameters['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParameters['search'] = search;
      }
      if (sort != null && sort.isNotEmpty) {
        queryParameters['sort'] = sort;
      }
      if (mine) {
        queryParameters['mine'] = true;
      }

      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances';
      final response = await dio.get(
        fullUrl,
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final payload = response.data;
        List<dynamic> list = [];
        if (payload is List) {
          list = payload;
        } else if (payload is Map) {
          final rawData = payload['data'];
          list = rawData is List ? rawData : (rawData != null ? rawData['data'] ?? [] : []);
        }
        return list.map((json) => VehicleMaintenance.fromJson(json)).toList();
      }
      return [];
    } catch (e, st) {
      debugPrint('[VehicleMaintenanceService] getVehicleMaintenances Error: $e\n$st');
      return [];
    }
  }

  Future<VehicleMaintenance?> getById(int id) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$id';
      final response = await dio.get(fullUrl);

      if (response.statusCode == 200) {
        final payload = response.data;
        final rawData = (payload is Map && payload['data'] != null) ? payload['data'] : payload;
        return VehicleMaintenance.fromJson(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] getById Error: $e');
      return null;
    }
  }

  Future<VehicleMaintenance?> create(Map<String, dynamic> payload) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances';
      final response = await dio.post(fullUrl, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = response.data['data'] ?? response.data;
        return VehicleMaintenance.fromJson(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] create Error: $e');
      rethrow;
    }
  }

  Future<VehicleMaintenance?> update(int id, Map<String, dynamic> payload) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$id';
      final response = await dio.put(fullUrl, data: payload);

      if (response.statusCode == 200) {
        final rawData = response.data['data'] ?? response.data;
        return VehicleMaintenance.fromJson(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] update Error: $e');
      rethrow;
    }
  }

  Future<bool> delete(int id) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$id';
      final response = await dio.delete(fullUrl);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] delete Error: $e');
      rethrow;
    }
  }

  Future<VehicleMaintenanceDocument?> addDocument(int maintenanceId, Map<String, dynamic> payload) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$maintenanceId/documents';
      final response = await dio.post(fullUrl, data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = response.data['data'] ?? response.data;
        return VehicleMaintenanceDocument.fromJson(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] addDocument Error: $e');
      rethrow;
    }
  }

  Future<bool> deleteDocument(int documentId) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/documents/$documentId';
      final response = await dio.delete(fullUrl);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] deleteDocument Error: $e');
      rethrow;
    }
  }

  Future<VehicleMaintenance?> runOcrForMaintenance(int maintenanceId) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$maintenanceId/ocr';
      final response = await dio.post(fullUrl);

      if (response.statusCode == 200) {
        final rawData = response.data['data'] ?? response.data;
        return VehicleMaintenance.fromJson(rawData);
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] runOcrForMaintenance Error: $e');
      rethrow;
    }
  }

  Future<List<VehicleMaintenanceHistory>> getHistory(int id) async {
    try {
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$id/history';
      final response = await dio.get(fullUrl);

      if (response.statusCode == 200) {
        final rawData = response.data['data'];
        if (rawData != null) {
          final List<dynamic> list = rawData is List ? rawData : rawData['data'] ?? [];
          return list.map((json) => VehicleMaintenanceHistory.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] getHistory Error: $e');
      return [];
    }
  }

  Future<bool> runWorkflowAction(int id, String action, {String? note, String? reason}) async {
    try {
      final endpointByAction = {
        'submit': 'submit',
        'dispatch_approve': 'dispatch-approve',
        'dispatch_reject': 'dispatch-reject',
        'production_approve': 'production-approve',
        'production_reject': 'production-reject',
      };
      
      final endpoint = endpointByAction[action] ?? action;
      final String fullUrl = '${AppEndpoints.apiBaseUrl}vehicle-maintenances/$id/$endpoint';
      
      final Map<String, dynamic> body = {};
      if (action.contains('reject')) {
        body['reason'] = reason ?? note ?? '';
      } else {
        if (note != null) body['note'] = note;
      }

      final response = await dio.post(fullUrl, data: body);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] runWorkflowAction Error: $e');
      rethrow;
    }
  }

  Future<String?> extractOcr(String filePath) async {
    try {
      final String fullUrl = '${AppEndpoints.webBaseUrl}/api/ocr';
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await dio.post(fullUrl, data: formData);

      if (response.statusCode == 200) {
        return response.data['text'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[VehicleMaintenanceService] extractOcr Error: $e');
      return null;
    }
  }
}
