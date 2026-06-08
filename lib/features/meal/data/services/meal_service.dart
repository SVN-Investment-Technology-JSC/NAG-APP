import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/meal/data/models/meal_model.dart';

class MealService {
  static final Dio _webDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static const double stationLat = 17.490144886448913;
  static const double stationLng = 106.55922219182935;
  static const double radiusMeters = 150;

  MealService();

  /// Fetch personnel list from Next.js API
  Future<List<Personnel>> fetchPersonnel() async {
    try {
      final res = await _webDio.get(
        '${AppEndpoints.webBaseUrl}/api/google-sheets/attendance/personnel',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data['personnel'] as List<dynamic>? ?? [];
        return list
            .map((e) => Personnel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MEAL] Personnel fetch error: $e');
    }
    return [];
  }

  /// Fetch vehicle-personnel mapping from Next.js API
  Future<Map<String, List<String>>> fetchPlateToNames() async {
    try {
      final res = await _webDio.get(
        '${AppEndpoints.webBaseUrl}/api/google-sheets/attendance/vehicle-personnel',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode == 200 && res.data != null) {
        final ptn = res.data['plateToNames'] as Map<String, dynamic>? ?? {};
        return ptn.map((k, v) =>
            MapEntry(k, (v as List<dynamic>).map((e) => e.toString()).toList()));
      }
    } catch (e) {
      debugPrint('[MEAL] Vehicle-personnel fetch error: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>?> getReport(String fromDate, String toDate) async {
    try {
      final res = await ApiClient.dio.get(
        'user-meal-status/report',
        queryParameters: {'from': fromDate, 'to': toDate},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        return data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MEAL] getReport error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] getReport error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] getReport error response: ${e.response?.data}');
      }
    }
    return null;
  }

  Future<dynamic> createRun(Map<String, dynamic> payload) async {
    try {
      final res = await ApiClient.dio.post(
        'meal-check/runs',
        data: payload,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        return data['meal_check_run_id'];
      }
    } catch (e) {
      debugPrint('[MEAL] createRun error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] createRun error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] createRun error response: ${e.response?.data}');
      }
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getRun(dynamic runId) async {
    try {
      final res = await ApiClient.dio.get(
        'meal-check/runs/$runId',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        return data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MEAL] getRun error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] getRun error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] getRun error response: ${e.response?.data}');
      }
    }
    return null;
  }

  Future<Map<String, bool>> checkConfigOk(String dateStr) async {
    bool hasPump = false;
    bool hasMixer = false;
    bool hasTask = false;

    try {
      // 1. Check arrangement (Pump & Mixer)
      final dayRes = await ApiClient.dio.get(
        'work-arrangement-days',
        queryParameters: {'arrangement_date': dateStr, 'limit': 10},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => status != null && (status == 200 || status == 404),
        ),
      );
      
      if (dayRes.statusCode == 200 && dayRes.data != null) {
        final days = dayRes.data['data'] ?? dayRes.data['work_arrangement_days'] ?? dayRes.data['items'] ?? [];
        if (days.isNotEmpty) {
          final dayId = days.first['work_arrangement_day_id'] ?? days.first['id'];
          if (dayId != null) {
            final itemsRes = await ApiClient.dio.get(
              'work-arrangement-items',
              queryParameters: {'work_arrangement_day_id': dayId, 'limit': 1000},
              options: Options(
                headers: {'Accept': 'application/json'},
                validateStatus: (status) => status != null && (status == 200 || status == 404),
              ),
            );
            if (itemsRes.statusCode == 200 && itemsRes.data != null) {
              final items = itemsRes.data['data'] ?? itemsRes.data['work_arrangement_items'] ?? itemsRes.data['items'] ?? [];
              if (items.isNotEmpty) {
                 hasPump = true; // simplified check
                 hasMixer = true; 
              }
            }
          }
        }
      }

      // 2. Check task
      final taskRes = await ApiClient.dio.get(
        'work-tasks',
        queryParameters: {'work_date': dateStr, 'limit': 1000},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => status != null && (status == 200 || status == 404),
        ),
      );
      if (taskRes.statusCode != null && taskRes.statusCode! >= 200 && taskRes.statusCode! < 300 && taskRes.data != null) {
        final tasks = taskRes.data['data'] ?? taskRes.data['work_tasks'] ?? taskRes.data['items'] ?? [];
        if (tasks.isNotEmpty) {
           hasTask = true; 
        }
      }
    } catch (e) {
      debugPrint('[MEAL] checkConfigOk error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] checkConfigOk error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] checkConfigOk error response: ${e.response?.data}');
      }
    }

    return {
      'hasPump': hasPump,
      'hasMixer': hasMixer,
      'hasTask': hasTask,
    };
  }

  Future<Map<String, dynamic>?> upsertUserMealStatus({
    required int userId,
    required String workDate,
    required String mealSlot,
    required bool isAllowance,
  }) async {
    try {
      final res = await ApiClient.dio.post(
        'user-meal-status',
        data: {
          'user_id': userId,
          'work_date': workDate,
          'meal_slot': mealSlot,
          'is_allowance': isAllowance,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300 && res.data != null) {
        final data = res.data['data'] ?? res.data;
        return data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[MEAL] upsertUserMealStatus error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] upsertUserMealStatus error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] upsertUserMealStatus error response: ${e.response?.data}');
      }
    }
    return null;
  }

  Future<List<UserAssignment>> fetchUserAssignments() async {
    try {
      final res = await ApiClient.dio.get(
        'user-assignments',
        queryParameters: {'limit': 1000},
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300 && res.data != null) {
        final list = (res.data['data'] ?? res.data['user_assignments'] ?? res.data['items'] ?? res.data) as List<dynamic>? ?? [];
        return list
            .map((e) => UserAssignment.fromJson(e as Map<String, dynamic>))
            .where((u) => !u.deleteFlag)
            .toList();
      }
    } catch (e) {
      debugPrint('[MEAL] fetchUserAssignments error: $e');
      if (e is DioException) {
        debugPrint('[MEAL] fetchUserAssignments error status: ${e.response?.statusCode}');
        debugPrint('[MEAL] fetchUserAssignments error response: ${e.response?.data}');
      }
    }
    return [];
  }
}
