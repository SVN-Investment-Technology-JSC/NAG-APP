class OrderModel {
  final int orderId;
  final int orderNumber;
  final String orderStatus;
  final String orderInitDatetime;
  final String? orderStartDatetime;
  final String? orderEndDatetime;
  final String? orderDescription;
  final String? checkinTimeStation;
  final String? checkoutTimeStation;
  final OrderMulti? orderMulti;
  final OrderUser? users;
  final OrderVehicle? vehicles;
  final OrderStation? stations;
  final String? updatedAt;
  final int? updatedBy;

  OrderModel({
    required this.orderId,
    required this.orderNumber,
    required this.orderStatus,
    required this.orderInitDatetime,
    this.orderStartDatetime,
    this.orderEndDatetime,
    this.orderDescription,
    this.checkinTimeStation,
    this.checkoutTimeStation,
    this.orderMulti,
    this.users,
    this.vehicles,
    this.stations,
    this.updatedAt,
    this.updatedBy,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderId: json['order_id'] ?? 0,
      orderNumber: json['order_number'] ?? 0,
      orderStatus: json['order_status'] ?? '',
      orderInitDatetime: json['order_init_datetime'] ?? '',
      orderStartDatetime: json['order_start_datetime'],
      orderEndDatetime: json['order_end_datetime'],
      orderDescription: json['order_description'],
      checkinTimeStation: json['checkin_time_station'],
      checkoutTimeStation: json['checkout_time_station'],
      orderMulti: json['order_multi'] != null
          ? OrderMulti.fromJson(json['order_multi'])
          : null,
      users: json['users'] != null ? OrderUser.fromJson(json['users']) : null,
      vehicles: json['vehicles'] != null
          ? OrderVehicle.fromJson(json['vehicles'])
          : null,
      stations: json['stations'] != null
          ? OrderStation.fromJson(json['stations'])
          : null,
      updatedAt: json['updated_at'],
      updatedBy: json['updated_by'],
    );
  }

  OrderModel copyWith({
    int? orderId,
    int? orderNumber,
    String? orderStatus,
    String? orderInitDatetime,
    String? orderStartDatetime,
    String? orderEndDatetime,
    String? orderDescription,
    String? checkinTimeStation,
    String? checkoutTimeStation,
    OrderMulti? orderMulti,
    OrderUser? users,
    OrderVehicle? vehicles,
    OrderStation? stations,
    String? updatedAt,
    int? updatedBy,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      orderStatus: orderStatus ?? this.orderStatus,
      orderInitDatetime: orderInitDatetime ?? this.orderInitDatetime,
      orderStartDatetime: orderStartDatetime ?? this.orderStartDatetime,
      orderEndDatetime: orderEndDatetime ?? this.orderEndDatetime,
      orderDescription: orderDescription ?? this.orderDescription,
      checkinTimeStation: checkinTimeStation ?? this.checkinTimeStation,
      checkoutTimeStation: checkoutTimeStation ?? this.checkoutTimeStation,
      orderMulti: orderMulti ?? this.orderMulti,
      users: users ?? this.users,
      vehicles: vehicles ?? this.vehicles,
      stations: stations ?? this.stations,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

class OrderUser {
  final int userId;
  final String userFullName;
  final String username;
  final String role;

  OrderUser({
    required this.userId,
    required this.userFullName,
    required this.username,
    required this.role,
  });

  factory OrderUser.fromJson(Map<String, dynamic> json) {
    return OrderUser(
      userId: json['user_id'] ?? 0,
      userFullName: json['user_full_name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class OrderVehicle {
  final int vehicleId;
  final String vehicleLicensePlate;
  final String vehicleStatus;

  OrderVehicle({
    required this.vehicleId,
    required this.vehicleLicensePlate,
    required this.vehicleStatus,
  });

  factory OrderVehicle.fromJson(Map<String, dynamic> json) {
    return OrderVehicle(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      vehicleStatus: json['vehicle_status'] ?? '',
    );
  }
}

class OrderStation {
  final int stationId;
  final String stationName;
  final String stationAddress;

  OrderStation({
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
  });

  factory OrderStation.fromJson(Map<String, dynamic> json) {
    return OrderStation(
      stationId: json['station_id'] ?? 0,
      stationName: json['station_name'] ?? '',
      stationAddress: json['station_address'] ?? '',
    );
  }
}

class OrderMulti {
  final double distanceStart;
  final int nStopStart;
  final double distanceEnd;
  final int nStopEnd;
  final int stopDurationSeconds;
  final String? checkinTimeStation;
  final String? checkoutTimeStation;

  OrderMulti({
    required this.distanceStart,
    required this.nStopStart,
    required this.distanceEnd,
    required this.nStopEnd,
    this.stopDurationSeconds = 0,
    this.checkinTimeStation,
    this.checkoutTimeStation,
  });

  factory OrderMulti.fromJson(Map<String, dynamic> json) {
    return OrderMulti(
      distanceStart: (json['distance_start'] as num?)?.toDouble() ?? 0,
      nStopStart: (json['nStop_start'] as num?)?.toInt() ?? 0,
      distanceEnd: (json['distance_end'] as num?)?.toDouble() ?? 0,
      nStopEnd: (json['nStop_end'] as num?)?.toInt() ?? 0,
      stopDurationSeconds: (json['stop_duration_seconds'] as num?)?.toInt() ?? 0,
      checkinTimeStation: json['checkin_time_station'],
      checkoutTimeStation: json['checkout_time_station'],
    );
  }

  double get distanceKm => (distanceEnd - distanceStart).abs();
  int get stopCount => (nStopEnd - nStopStart).abs();
}
