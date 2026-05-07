import 'package:intl/intl.dart';
import 'package:json_annotation/json_annotation.dart';

class ProductionReportResponse {
  final String from;
  final String to;
  final String groupBy;
  final ProductionSummary summary;
  final List<ProductionSeriesItem> series;
  final List<ProductionTopVehicle> topVehicles;
  final List<ProductionTopStation> topStations;

  ProductionReportResponse({
    required this.from,
    required this.to,
    required this.groupBy,
    required this.summary,
    required this.series,
    required this.topVehicles,
    required this.topStations,
  });

  factory ProductionReportResponse.fromJson(Map<String, dynamic> json) {
    return ProductionReportResponse(
      from: json['from'] ?? '',
      to: json['to'] ?? '',
      groupBy: json['group_by'] ?? 'day',
      summary: ProductionSummary.fromJson(json['summary'] ?? {}),
      series: (json['series'] as List? ?? [])
          .map((e) => ProductionSeriesItem.fromJson(e))
          .toList(),
      topVehicles: (json['top_vehicles'] as List? ?? [])
          .map((e) => ProductionTopVehicle.fromJson(e))
          .toList(),
      topStations: (json['top_stations'] as List? ?? [])
          .map((e) => ProductionTopStation.fromJson(e))
          .toList(),
    );
  }

  static ProductionReportResponse aggregate(List<ProductionReportResponse> reports, String from, String to, String groupBy) {
    if (reports.isEmpty) {
      return ProductionReportResponse(
        from: from,
        to: to,
        groupBy: groupBy,
        summary: ProductionSummary.empty(),
        series: [],
        topVehicles: [],
        topStations: [],
      );
    }

    final summary = ProductionSummary.empty();
    final Map<String, ProductionSeriesItem> seriesMap = {};
    final Map<int, ProductionTopVehicle> vehicleMap = {};
    final Map<int, ProductionTopStation> stationMap = {};

    for (var report in reports) {
      // Aggregate summary
      summary.totalOrders += report.summary.totalOrders;
      summary.completed += report.summary.completed;
      summary.running += report.summary.running;
      summary.collecting += report.summary.collecting;
      summary.transporting += report.summary.transporting;
      summary.pending += report.summary.pending;
      summary.canceled += report.summary.canceled;
      summary.totalDistanceKm += report.summary.totalDistanceKm;

      // Aggregate series
      for (var item in report.series) {
        if (!seriesMap.containsKey(item.period)) {
          seriesMap[item.period] = ProductionSeriesItem(
            period: item.period,
            totalOrders: item.totalOrders,
            completed: item.completed,
            running: item.running,
            collecting: item.collecting,
            transporting: item.transporting,
            pending: item.pending,
            canceled: item.canceled,
            distanceKm: item.distanceKm,
          );
        } else {
          final prev = seriesMap[item.period]!;
          seriesMap[item.period] = ProductionSeriesItem(
            period: item.period,
            totalOrders: prev.totalOrders + item.totalOrders,
            completed: prev.completed + item.completed,
            running: prev.running + item.running,
            collecting: prev.collecting + item.collecting,
            transporting: prev.transporting + item.transporting,
            pending: prev.pending + item.pending,
            canceled: prev.canceled + item.canceled,
            distanceKm: prev.distanceKm + item.distanceKm,
          );
        }
      }

      // Aggregate vehicles
      for (var item in report.topVehicles) {
        if (!vehicleMap.containsKey(item.vehicleId)) {
          vehicleMap[item.vehicleId] = item;
        } else {
          final prev = vehicleMap[item.vehicleId]!;
          vehicleMap[item.vehicleId] = ProductionTopVehicle(
            vehicleId: item.vehicleId,
            vehicleName: item.vehicleName,
            vehicleLicensePlate: item.vehicleLicensePlate,
            totalOrders: prev.totalOrders + item.totalOrders,
            totalDistanceKm: prev.totalDistanceKm + item.totalDistanceKm,
          );
        }
      }

      // Aggregate stations
      for (var item in report.topStations) {
        if (!stationMap.containsKey(item.stationId)) {
          stationMap[item.stationId] = item;
        } else {
          final prev = stationMap[item.stationId]!;
          stationMap[item.stationId] = ProductionTopStation(
            stationId: item.stationId,
            stationName: item.stationName,
            totalOrders: prev.totalOrders + item.totalOrders,
          );
        }
      }
    }

    // FILL GAPS in series (Ensure every day/period between from and to exists)
    final List<ProductionSeriesItem> filledSeries = [];
    final start = DateTime.tryParse(from) ?? DateTime.now();
    final end = DateTime.tryParse(to) ?? DateTime.now();

    if (groupBy == 'day') {
      for (int i = 0; i <= end.difference(start).inDays; i++) {
        final d = start.add(Duration(days: i));
        final p = DateFormat('yyyy-MM-dd').format(d);
        if (seriesMap.containsKey(p)) {
          filledSeries.add(seriesMap[p]!);
        } else {
          filledSeries.add(ProductionSeriesItem(
            period: p,
            totalOrders: 0,
            completed: 0,
            running: 0,
            collecting: 0,
            transporting: 0,
            pending: 0,
            canceled: 0,
            distanceKm: 0.0,
          ));
        }
      }
    } else {
      // For week/month, just use what we have sorted
      filledSeries.addAll(seriesMap.values.toList()..sort((a, b) => a.period.compareTo(b.period)));
    }
    
    final sortedVehicles = vehicleMap.values.toList()
      ..sort((a, b) => b.totalOrders.compareTo(a.totalOrders));

    final sortedStations = stationMap.values.toList()
      ..sort((a, b) => b.totalOrders.compareTo(a.totalOrders));

    return ProductionReportResponse(
      from: from,
      to: to,
      groupBy: groupBy,
      summary: summary,
      series: filledSeries,
      topVehicles: sortedVehicles,
      topStations: sortedStations,
    );
  }
}

class ProductionSummary {
  int totalOrders;
  int completed;
  int running;
  int collecting;
  int transporting;
  int pending;
  int canceled;
  double totalDistanceKm;

  ProductionSummary({
    required this.totalOrders,
    required this.completed,
    required this.running,
    required this.collecting,
    required this.transporting,
    required this.pending,
    required this.canceled,
    required this.totalDistanceKm,
  });

  factory ProductionSummary.empty() => ProductionSummary(
        totalOrders: 0,
        completed: 0,
        running: 0,
        collecting: 0,
        transporting: 0,
        pending: 0,
        canceled: 0,
        totalDistanceKm: 0.0,
      );

  factory ProductionSummary.fromJson(Map<String, dynamic> json) {
    return ProductionSummary(
      totalOrders: json['total_orders'] ?? 0,
      completed: json['completed'] ?? 0,
      running: json['running'] ?? 0,
      collecting: json['collecting'] ?? 0,
      transporting: json['transporting'] ?? 0,
      pending: json['pending'] ?? 0,
      canceled: json['canceled'] ?? 0,
      totalDistanceKm: (json['total_distance_km'] ?? 0).toDouble(),
    );
  }
}

class ProductionSeriesItem {
  final String period;
  final int totalOrders;
  final int completed;
  final int running;
  final int collecting;
  final int transporting;
  final int pending;
  final int canceled;
  final double distanceKm;

  ProductionSeriesItem({
    required this.period,
    required this.totalOrders,
    required this.completed,
    required this.running,
    required this.collecting,
    required this.transporting,
    required this.pending,
    required this.canceled,
    required this.distanceKm,
  });

  factory ProductionSeriesItem.fromJson(Map<String, dynamic> json) {
    return ProductionSeriesItem(
      period: json['period'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
      completed: json['completed'] ?? 0,
      running: json['running'] ?? 0,
      collecting: json['collecting'] ?? 0,
      transporting: json['transporting'] ?? 0,
      pending: json['pending'] ?? 0,
      canceled: json['canceled'] ?? 0,
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
    );
  }
}

class ProductionTopVehicle {
  final int vehicleId;
  final String vehicleName;
  final String vehicleLicensePlate;
  final int totalOrders;
  final double totalDistanceKm;

  ProductionTopVehicle({
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleLicensePlate,
    required this.totalOrders,
    required this.totalDistanceKm,
  });

  factory ProductionTopVehicle.fromJson(Map<String, dynamic> json) {
    return ProductionTopVehicle(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'] ?? '',
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
      totalDistanceKm: (json['total_distance_km'] ?? 0).toDouble(),
    );
  }
}

class ProductionTopStation {
  final int stationId;
  final String stationName;
  final int totalOrders;

  ProductionTopStation({
    required this.stationId,
    required this.stationName,
    required this.totalOrders,
  });

  factory ProductionTopStation.fromJson(Map<String, dynamic> json) {
    return ProductionTopStation(
      stationId: json['station_id'] ?? 0,
      stationName: json['station_name'] ?? '',
      totalOrders: json['total_orders'] ?? 0,
    );
  }
}
