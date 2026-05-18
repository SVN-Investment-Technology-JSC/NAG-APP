class TankerQueueSnapshotItem {
  final int position;
  final String vehicleName;
  final String vehicleLicensePlate;
  final int orderId;
  final int vehicleId;
  final String orderStatus;

  TankerQueueSnapshotItem({
    required this.position,
    required this.vehicleName,
    required this.vehicleLicensePlate,
    required this.orderId,
    required this.vehicleId,
    required this.orderStatus,
  });

  factory TankerQueueSnapshotItem.fromJson(Map<String, dynamic> json) {
    return TankerQueueSnapshotItem(
      position: json['position'] ?? 0,
      vehicleName: json['vehicle_name'] ?? '',
      vehicleLicensePlate: json['vehicle_license_plate'] ?? '',
      orderId: json['order_id'] ?? 0,
      vehicleId: json['vehicle_id'] ?? 0,
      orderStatus: json['order_status'] ?? '',
    );
  }
}
