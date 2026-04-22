import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/meal/data/models/meal_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';

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

  /// Fetch GPS history for a vehicle on a specific day and time slot
  Future<List<Map<String, dynamic>>> _fetchHistory(
      String vehicleId, DateTime day, MealSlot slot) async {
    try {
      final dayStr = DateFormat('dd-MM-yyyy').format(day);
      final fromDate =
          '$dayStr,${slot.fromH.toString().padLeft(2, '0')}:${slot.fromM.toString().padLeft(2, '0')}';
      final toDate =
          '$dayStr,${slot.toH.toString().padLeft(2, '0')}:${slot.toM.toString().padLeft(2, '0')}';

      final res = await _webDio.post(
        '${AppEndpoints.webBaseUrl}/api/vtracking/history',
        data: {
          'vehicleId': vehicleId,
          'fromDate': fromDate,
          'toDate': toDate,
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (res.statusCode == 200 && res.data != null) {
        return (res.data['logs'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
      }
    } catch (e) {
      debugPrint('[MEAL] History fetch error: $e');
    }
    return [];
  }

  Future<List<VtrackingVehicle>> _fetchVehiclesViaProxy() async {
    try {
      final res = await _webDio.get(
        '${AppEndpoints.webBaseUrl}/api/vtracking/gps',
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (res.statusCode == 200 && res.data != null) {
        final list = res.data['vehicles'] as List<dynamic>? ?? [];
        return list.map((v) {
          final m = v as Map<String, dynamic>;
          return VtrackingVehicle(
            id: (m['id'] ?? '').toString(),
            deviceId: (m['device_id'] ?? '').toString(),
            vehicleName: (m['vehicle_name'] ?? '').toString(),
            licensePlate: (m['license_plate'] ?? '').toString(),
            latitude: (m['latitude'] as num?)?.toDouble() ?? 0,
            longitude: (m['longitude'] as num?)?.toDouble() ?? 0,
            speed: (m['speed'] as num?)?.toDouble() ?? 0,
            status: (m['status'] ?? 'unknown').toString(),
            geocoding: (m['geocoding'] ?? '').toString(),
            direction: (m['direction'] as num?)?.toInt() ?? 0,
            timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MEAL] VTracking GPS proxy error: $e');
    }
    return [];
  }

  /// Haversine distance in meters
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _toRad(double d) => d * pi / 180;

  static String _normPlate(String plate) {
    final digits = plate.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 5 ? digits : digits.substring(digits.length - 5);
  }

  /// Generate list of days between [from] and [to] inclusive
  static List<DateTime> _daysBetween(DateTime from, DateTime to) {
    final days = <DateTime>[];
    var d = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!d.isAfter(end)) {
      days.add(d);
      d = d.add(const Duration(days: 1));
    }
    return days;
  }

  /// Check meals for a date range, fetching one vehicle/day/slot at a time.
  ///
  /// [onProgress]: (current, total) — called after each fetch
  /// [onDataUpdate]: called after each meal found with the latest mealData
  ///   so UI can rebuild progressively.
  /// [onError]: called with error message when something goes wrong
  Future<void> checkMeals({
    required DateTime fromDate,
    required DateTime toDate,
    required List<MealSlot> slots,
    required List<Personnel> personnel,
    required Map<String, List<String>> plateToNames,
    required MealDataMap mealData,
    void Function(int current, int total)? onProgress,
    void Function()? onDataUpdate,
    void Function(String error)? onError,
  }) async {
    final vehicles = await _fetchVehiclesViaProxy();
    if (vehicles.isEmpty) {
      debugPrint('[MEAL] No vehicles returned from VTracking proxy');
      onError?.call('Không lấy được danh sách xe từ VTracking');
    }
    final allDays = _daysBetween(fromDate, toDate);
    final dateFmt = DateFormat('yyyy-MM-dd');

    // Init meal data for all personnel × all days
    for (final p in personnel) {
      mealData.putIfAbsent(p.hoTen, () => {});
      for (final day in allDays) {
        final ds = dateFmt.format(day);
        mealData[p.hoTen]!.putIfAbsent(ds, () => DayMeals());
      }
    }

    final normMap = <String, List<String>>{};
    for (final entry in plateToNames.entries) {
      normMap[_normPlate(entry.key)] = entry.value;
    }

    final totalSteps = vehicles.length * allDays.length * slots.length;
    var step = 0;
    var matchedVehicles = 0;
    var historyErrors = 0;
    onProgress?.call(0, totalSteps);

    for (final vehicle in vehicles) {
      final driverNames = normMap[_normPlate(vehicle.licensePlate)];
      if (driverNames == null || driverNames.isEmpty) {
        step += allDays.length * slots.length;
        onProgress?.call(step, totalSteps);
        continue;
      }
      matchedVehicles++;

      // Ensure driver names exist in mealData
      for (final name in driverNames) {
        mealData.putIfAbsent(name, () => {});
        for (final day in allDays) {
          final ds = dateFmt.format(day);
          mealData[name]!.putIfAbsent(ds, () => DayMeals());
        }
      }

      for (final day in allDays) {
        final ds = dateFmt.format(day);

        for (final slot in slots) {
          step++;
          onProgress?.call(step, totalSteps);

          // Skip if all drivers already have this slot for this day
          final allHaveSlot = driverNames.every((name) {
            final dm = mealData[name]?[ds];
            if (dm == null) return true;
            if (slot.key == 'sang') return dm.sang;
            if (slot.key == 'trua') return dm.trua;
            return dm.toi;
          });
          if (allHaveSlot) continue;

          try {
            final logs = await _fetchHistory(vehicle.id, day, slot);
            for (final log in logs) {
              final val = log['value'] as Map<String, dynamic>? ?? {};
              final lat = (val['latitude'] as num?)?.toDouble() ?? 0;
              final lng = (val['longitude'] as num?)?.toDouble() ?? 0;
              if (lat == 0 || lng == 0) continue;

              final dist = _haversine(stationLat, stationLng, lat, lng);
              if (dist > radiusMeters) {
                // Vehicle was away from station -> had meal
                for (final name in driverNames) {
                  final dm = mealData.putIfAbsent(name, () => {})[ds] ??= DayMeals();
                  if (slot.key == 'sang') dm.sang = true;
                  if (slot.key == 'trua') dm.trua = true;
                  if (slot.key == 'toi') dm.toi = true;
                }
                onDataUpdate?.call();
                break;
              }
            }
          } catch (e) {
            historyErrors++;
            debugPrint('[MEAL] Check error for ${vehicle.licensePlate} on ${dateFmt.format(day)} ${slot.key}: $e');
          }
        }
      }
    }

    debugPrint('[MEAL] Done: ${vehicles.length} vehicles, $matchedVehicles matched plates, $historyErrors errors, ${allDays.length} days, ${slots.length} slots');
    if (matchedVehicles == 0 && vehicles.isNotEmpty) {
      onError?.call('Không có xe nào khớp biển số với bảng phân công (${vehicles.length} xe, ${normMap.length} biển số trong bảng)');
    }
    if (historyErrors > 0) {
      onError?.call('$historyErrors lỗi khi lấy lịch sử GPS');
    }
  }
}
