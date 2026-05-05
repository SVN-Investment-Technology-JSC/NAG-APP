class EndOfDayStatusResponse {
  final String date;
  final int total;
  final int abnormalTotal;
  final List<EndOfDayVehicle> vehicles;

  EndOfDayStatusResponse({
    required this.date,
    required this.total,
    required this.abnormalTotal,
    required this.vehicles,
  });

  factory EndOfDayStatusResponse.fromJson(Map<String, dynamic> json) {
    return EndOfDayStatusResponse(
      date: json['date'] ?? '',
      total: json['total'] ?? 0,
      abnormalTotal: json['abnormal_total'] ?? 0,
      vehicles: (json['vehicles'] as List<dynamic>?)
              ?.map((v) => EndOfDayVehicle.fromJson(v))
              .toList() ??
          [],
    );
  }
}

class EndOfDayVehicle {
  final int vehicleId;
  final String vehicleName;
  final String vehicleLicensePlate;
  final String driverName;
  final String finalStatus;
  final bool isAbnormal;
  final String? finishedAt;
  final String operationNote;
  final List<String>? operationNotes;
  final List<EndOfDayOperationItem>? operationItems;
  final List<String>? abnormalNotes;
  final int orderId;
  final int orderNumber;
  final String orderStatus;
  final String stationName;

  EndOfDayVehicle({
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleLicensePlate,
    required this.driverName,
    required this.finalStatus,
    required this.isAbnormal,
    this.finishedAt,
    required this.operationNote,
    this.operationNotes,
    this.operationItems,
    this.abnormalNotes,
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.stationName,
  });

  factory EndOfDayVehicle.fromJson(Map<String, dynamic> json) {
    return EndOfDayVehicle(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'] ?? '',
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      driverName: json['driver_name'] ?? '',
      finalStatus: json['final_status'] ?? '',
      isAbnormal: json['is_abnormal'] ?? false,
      finishedAt: json['finished_at'],
      operationNote: json['operation_note'] ?? '',
      operationNotes: (json['operation_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      operationItems: (json['operation_items'] as List<dynamic>?)
          ?.map((e) => EndOfDayOperationItem.fromJson(e))
          .toList(),
      abnormalNotes: (json['abnormal_notes'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? 0,
      orderStatus: json['order_status'] ?? '',
      stationName: json['station_name'] ?? '',
    );
  }
}

class EndOfDayOperationItem {
  final String event;
  final String message;
  final String level; // "warning" | "info" | "status"
  final String? occurredAt;
  final int? orderId;
  final String? stationName;

  EndOfDayOperationItem({
    required this.event,
    required this.message,
    required this.level,
    this.occurredAt,
    this.orderId,
    this.stationName,
  });

  factory EndOfDayOperationItem.fromJson(Map<String, dynamic> json) {
    return EndOfDayOperationItem(
      event: json['event'] ?? '',
      message: json['message'] ?? '',
      level: json['level'] ?? 'info',
      occurredAt: json['occurred_at'],
      orderId: json['order_id'],
      stationName: json['station_name'],
    );
  }
}
