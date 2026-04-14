import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vehicle_management/core/network/app_endpoints.dart';
import 'package:vehicle_management/features/attendance/data/models/attendance_model.dart';

class AttendanceService {
  final Dio dio;

  AttendanceService(this.dio);

  Future<AttendanceResponse> getAttendance({DateTime? date}) async {
    try {
      final dateStr = DateFormat('dd/MM/yyyy').format(date ?? DateTime.now());
      final url = '${AppEndpoints.webBaseUrl}/api/google-sheets/attendance';

      final response = await dio.get(
        url,
        queryParameters: {'date': dateStr},
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AttendanceResponse.fromJson(response.data as Map<String, dynamic>);
      }
      return _empty();
    } on DioException catch (e) {
      debugPrint('[ATTENDANCE] API Error: ${e.response?.statusCode}');
      debugPrint('[ATTENDANCE] Response: ${e.response?.data}');
      rethrow;
    } catch (e) {
      debugPrint('[ATTENDANCE] Error: $e');
      rethrow;
    }
  }

  AttendanceResponse _empty() => const AttendanceResponse(
        sheetDate: '',
        results: [],
        nhomNS: [],
        summary: AttendanceSummary(total: 0, working: 0, off: 0, half: 0),
      );
}
