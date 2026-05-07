import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';

class ReportService {
  final Dio _dio;

  ReportService(this._dio);

  Future<ProductionReportResponse> getProduction({
    int? vehicleId,
    int? stationId,
    String? from,
    String? to,
    String? groupBy,
  }) async {
    final queryParameters = <String, dynamic>{};
    if (vehicleId != null) queryParameters['vehicle_id'] = vehicleId;
    if (stationId != null) queryParameters['station_id'] = stationId;
    if (from != null) queryParameters['from'] = from;
    if (to != null) queryParameters['to'] = to;
    if (groupBy != null) queryParameters['group_by'] = groupBy;

    final response = await _dio.get(
      AppEndpoints.reportProduction,
      queryParameters: queryParameters,
    );

    return ProductionReportResponse.fromJson(response.data);
  }

  Future<List<dynamic>> getVehicleTypes() async {
    final response = await _dio.get(AppEndpoints.vehicleTypes);
    return response.data['data'] ?? [];
  }
}
