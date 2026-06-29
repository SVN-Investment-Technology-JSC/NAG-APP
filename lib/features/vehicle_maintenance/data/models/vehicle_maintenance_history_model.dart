class VehicleMaintenanceHistoryActor {
  final int id;
  final String? role;
  final String? roleLabel;
  final String? name;

  VehicleMaintenanceHistoryActor({
    required this.id,
    this.role,
    this.roleLabel,
    this.name,
  });

  factory VehicleMaintenanceHistoryActor.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenanceHistoryActor(
      id: json['id'] as int,
      role: json['role'] as String?,
      roleLabel: json['role_label'] as String?,
      name: json['name'] as String?,
    );
  }
}

class VehicleMaintenanceHistory {
  final int vehicleMaintenanceHistoryId;
  final int vehicleMaintenanceId;
  final String action;
  final String? fromStatus;
  final String? toStatus;
  final String? note;
  final VehicleMaintenanceHistoryActor actor;
  final DateTime createdAt;

  VehicleMaintenanceHistory({
    required this.vehicleMaintenanceHistoryId,
    required this.vehicleMaintenanceId,
    required this.action,
    this.fromStatus,
    this.toStatus,
    this.note,
    required this.actor,
    required this.createdAt,
  });

  factory VehicleMaintenanceHistory.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenanceHistory(
      vehicleMaintenanceHistoryId: json['vehicle_maintenance_history_id'] as int,
      vehicleMaintenanceId: json['vehicle_maintenance_id'] as int,
      action: json['action'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String?,
      note: json['note'] as String?,
      actor: VehicleMaintenanceHistoryActor.fromJson(json['actor'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
