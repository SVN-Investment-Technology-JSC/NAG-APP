import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';

class ParkingIdleEngineService {
  Future<ParkingIdleEngineSettings> getSettings() async {
    try {
      final response = await ApiClient.dio.get('/multi/parking-idle-engine');
      final data = response.data['data'] ?? response.data;
      final multiData = data['multi_data'] ?? {};
      return ParkingIdleEngineSettings.fromJson(multiData);
    } catch (e) {
      throw Exception('Failed to load settings: $e');
    }
  }

  Future<void> updateSettings(ParkingIdleEngineSettings settings) async {
    try {
      await ApiClient.dio.put(
        '/multi/parking-idle-engine',
        data: settings.toJson(),
      );
    } catch (e) {
      throw Exception('Failed to update settings: $e');
    }
  }

  Future<ParkingIdleEngineAlertsResponse> getAlerts({required bool warningOnly}) async {
    try {
      final response = await ApiClient.dio.get(
        '/fuel/parking-idle-engine-alerts',
        queryParameters: {
          'warning_only': warningOnly ? 1 : 0,
        },
      );
      final data = response.data['data'] ?? response.data;
      return ParkingIdleEngineAlertsResponse.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load alerts: $e');
    }
  }

  Future<ParkingIdleEngineHistoryResponse> getHistory({
    required int vehicleId,
    required int page,
    required int limit,
    String? from,
    String? to,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'vehicle_id': vehicleId,
        'page': page,
        'limit': limit,
      };
      if (from != null && from.isNotEmpty) {
        queryParams['from'] = from;
      }
      if (to != null && to.isNotEmpty) {
        queryParams['to'] = to;
      }

      final response = await ApiClient.dio.get(
        '/fuel/parking-idle-engine-history',
        queryParameters: queryParams,
      );
      final data = response.data['data'] ?? response.data;
      return ParkingIdleEngineHistoryResponse.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load history: $e');
    }
  }
}
