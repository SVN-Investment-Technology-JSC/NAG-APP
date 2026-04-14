class VehicleModel {
  final int vehicleId;
  final String vehicleName;
  final String vehicleLicensePlate;
  final String vehicleStatus;
  final String? vehicleDescription;
  final String? vehicleRfid;
  final int? vehicleTypeId;
  final int? userId;
  final VehicleUser? users;

  VehicleModel({
    required this.vehicleId,
    required this.vehicleName,
    required this.vehicleLicensePlate,
    required this.vehicleStatus,
    this.vehicleDescription,
    this.vehicleRfid,
    this.vehicleTypeId,
    this.userId,
    this.users,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      vehicleId: json['vehicle_id'] ?? 0,
      vehicleName: json['vehicle_name'] ?? '',
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      vehicleStatus: json['vehicle_status'] ?? '',
      vehicleDescription: json['vehicle_description'],
      vehicleRfid: json['vehicle_rfid'],
      vehicleTypeId: json['vehicle_type_id'],
      userId: json['user_id'],
      users: json['users'] != null ? VehicleUser.fromJson(json['users']) : null,
    );
  }
}

class VehicleUser {
  final int userId;
  final String userFullName;
  final String username;
  final String role;

  VehicleUser({
    required this.userId,
    required this.userFullName,
    required this.username,
    required this.role,
  });

  factory VehicleUser.fromJson(Map<String, dynamic> json) {
    return VehicleUser(
      userId: json['user_id'] ?? 0,
      userFullName: json['user_full_name'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
    );
  }
}
