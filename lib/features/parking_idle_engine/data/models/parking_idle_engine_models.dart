class ParkingIdleEngineSettings {
  final bool enabled;
  final double warningAfterMinutes;
  final String minConfidence;
  final double notificationTtlSeconds;

  ParkingIdleEngineSettings({
    required this.enabled,
    required this.warningAfterMinutes,
    required this.minConfidence,
    required this.notificationTtlSeconds,
  });

  factory ParkingIdleEngineSettings.fromJson(Map<String, dynamic> json) {
    return ParkingIdleEngineSettings(
      enabled: json['enabled'] ?? false,
      warningAfterMinutes: (json['warning_after_minutes'] ?? 0.0).toDouble(),
      minConfidence: json['min_confidence'] ?? 'high',
      notificationTtlSeconds: (json['notification_ttl_seconds'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'warning_after_minutes': warningAfterMinutes,
      'min_confidence': minConfidence,
      'notification_ttl_seconds': notificationTtlSeconds,
    };
  }
}

class ParkingIdleEngineAlert {
  final int vehicleId;
  final String vehicleName;
  final String vehicleLicensePlate;
  final int stationId;
  final String stationName;
  final int? orderId;
  final int? orderNumber;
  final String? orderStatus;
  final bool isCollectingAtStation;
  final bool inYard;
  final bool engineOn;
  final bool warningActive;
  final String? idleStartedAt;
  final double elapsedMinutes;
  final double idleLPerHour;
  final double estimatedIdleFuelLiters;
  final double warningAfterMinutes;
  final String engineState; // 'on' | 'off' | 'unknown'
  final String? engineSource;
  final String engineConfidence;
  final bool engineSignalAvailable;
  final String motionState;
  final double latitude;
  final double longitude;
  final String? geocoding;

  ParkingIdleEngineAlert({
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleLicensePlate,
    required this.stationId,
    required this.stationName,
    this.orderId,
    this.orderNumber,
    this.orderStatus,
    required this.isCollectingAtStation,
    required this.inYard,
    required this.engineOn,
    required this.warningActive,
    this.idleStartedAt,
    required this.elapsedMinutes,
    required this.idleLPerHour,
    required this.estimatedIdleFuelLiters,
    required this.warningAfterMinutes,
    required this.engineState,
    this.engineSource,
    required this.engineConfidence,
    required this.engineSignalAvailable,
    required this.motionState,
    required this.latitude,
    required this.longitude,
    this.geocoding,
  });

  factory ParkingIdleEngineAlert.fromJson(Map<String, dynamic> json) {
    return ParkingIdleEngineAlert(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'] ?? '',
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      stationId: json['station_id'] ?? 0,
      stationName: json['station_name'] ?? '',
      orderId: json['order_id'],
      orderNumber: json['order_number'],
      orderStatus: json['order_status'],
      isCollectingAtStation: json['is_collecting_at_station'] ?? false,
      inYard: json['in_yard'] ?? false,
      engineOn: json['engine_on'] ?? false,
      warningActive: json['warning_active'] ?? false,
      idleStartedAt: json['idle_started_at'],
      elapsedMinutes: (json['elapsed_minutes'] ?? 0.0).toDouble(),
      idleLPerHour: (json['idle_l_per_hour'] ?? 0.0).toDouble(),
      estimatedIdleFuelLiters: (json['estimated_idle_fuel_liters'] ?? 0.0).toDouble(),
      warningAfterMinutes: (json['warning_after_minutes'] ?? 0.0).toDouble(),
      engineState: json['engine_state'] ?? 'unknown',
      engineSource: json['engine_source'],
      engineConfidence: json['engine_confidence'] ?? 'low',
      engineSignalAvailable: json['engine_signal_available'] ?? false,
      motionState: json['motion_state'] ?? 'unknown',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      geocoding: json['geocoding'],
    );
  }
}

class ParkingIdleEngineAlertsResponse {
  final ParkingIdleEngineSettings settings;
  final int totalVehicles;
  final int inYardCount;
  final int warningCount;
  final int engineOnCount;
  final double estimatedIdleFuelLiters;
  final List<ParkingIdleEngineAlert> items;

  ParkingIdleEngineAlertsResponse({
    required this.settings,
    required this.totalVehicles,
    required this.inYardCount,
    required this.warningCount,
    required this.engineOnCount,
    required this.estimatedIdleFuelLiters,
    required this.items,
  });

  factory ParkingIdleEngineAlertsResponse.fromJson(Map<String, dynamic> json) {
    return ParkingIdleEngineAlertsResponse(
      settings: ParkingIdleEngineSettings.fromJson(json['settings'] ?? {}),
      totalVehicles: json['total_vehicles'] ?? 0,
      inYardCount: json['in_yard_count'] ?? 0,
      warningCount: json['warning_count'] ?? 0,
      engineOnCount: json['engine_on_count'] ?? 0,
      estimatedIdleFuelLiters: (json['estimated_idle_fuel_liters'] ?? 0.0).toDouble(),
      items: (json['items'] as List? ?? [])
          .map((e) => ParkingIdleEngineAlert.fromJson(e))
          .toList(),
    );
  }
}

class ParkingIdleEngineHistoryItem {
  final int multiId;
  final String sessionName;
  final String status;
  final int vehicleId;
  final String? vehicleName;
  final String? vehicleLicensePlate;
  final int? stationId;
  final String? stationName;
  final String idleStartedAt;
  final String? idleEndedAt;
  final double elapsedMinutes;
  final double idleLPerHour;
  final double estimatedIdleFuelLiters;
  final String engineState;
  final String? engineSource;
  final String engineConfidence;
  final bool engineSignalAvailable;
  final String motionState;
  final double vtrackingLatitude;
  final double vtrackingLongitude;
  final String geocoding;

  ParkingIdleEngineHistoryItem({
    required this.multiId,
    required this.sessionName,
    required this.status,
    required this.vehicleId,
    this.vehicleName,
    this.vehicleLicensePlate,
    this.stationId,
    this.stationName,
    required this.idleStartedAt,
    this.idleEndedAt,
    required this.elapsedMinutes,
    required this.idleLPerHour,
    required this.estimatedIdleFuelLiters,
    required this.engineState,
    this.engineSource,
    required this.engineConfidence,
    required this.engineSignalAvailable,
    required this.motionState,
    required this.vtrackingLatitude,
    required this.vtrackingLongitude,
    required this.geocoding,
  });

  factory ParkingIdleEngineHistoryItem.fromJson(Map<String, dynamic> json) {
    return ParkingIdleEngineHistoryItem(
      multiId: json['multi_id'] ?? 0,
      sessionName: json['session_name'] ?? '',
      status: json['status'] ?? 'closed',
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'],
      vehicleLicensePlate: json['vehicle_license_plate'],
      stationId: json['station_id'],
      stationName: json['station_name'],
      idleStartedAt: json['idle_started_at'] ?? '',
      idleEndedAt: json['idle_ended_at'],
      elapsedMinutes: (json['elapsed_minutes'] ?? 0.0).toDouble(),
      idleLPerHour: (json['idle_l_per_hour'] ?? 0.0).toDouble(),
      estimatedIdleFuelLiters: (json['estimated_idle_fuel_liters'] ?? 0.0).toDouble(),
      engineState: json['engine_state'] ?? 'unknown',
      engineSource: json['engine_source'],
      engineConfidence: json['engine_confidence'] ?? 'low',
      engineSignalAvailable: json['engine_signal_available'] ?? false,
      motionState: json['motion_state'] ?? 'unknown',
      vtrackingLatitude: (json['vtracking_latitude'] ?? 0.0).toDouble(),
      vtrackingLongitude: (json['vtracking_longitude'] ?? 0.0).toDouble(),
      geocoding: json['geocoding'] ?? '',
    );
  }
}

class ParkingIdleEngineHistoryResponse {
  final int total;
  final int page;
  final int limit;
  final List<ParkingIdleEngineHistoryItem> items;

  ParkingIdleEngineHistoryResponse({
    required this.total,
    required this.page,
    required this.limit,
    required this.items,
  });

  factory ParkingIdleEngineHistoryResponse.fromJson(Map<String, dynamic> json) {
    return ParkingIdleEngineHistoryResponse(
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 10,
      items: (json['items'] as List? ?? [])
          .map((e) => ParkingIdleEngineHistoryItem.fromJson(e))
          .toList(),
    );
  }
}
