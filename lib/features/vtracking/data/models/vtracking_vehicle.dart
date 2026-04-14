class VtrackingVehicle {
  final String id;
  final String deviceId;
  final String vehicleName;
  final String licensePlate;
  final double latitude;
  final double longitude;
  final double speed;
  final String status; // "run", "park", "unknown"
  final String geocoding;
  final int direction;
  final int timestamp;

  VtrackingVehicle({
    required this.id,
    required this.deviceId,
    required this.vehicleName,
    required this.licensePlate,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.status,
    required this.geocoding,
    required this.direction,
    required this.timestamp,
  });

  factory VtrackingVehicle.fromRawJson(Map<String, dynamic> v) {
    final attrs = (v['attributes'] as List<dynamic>?) ?? [];

    // Find "datas" attribute
    Map<String, dynamic> datas = {};
    String? plateNo;
    for (final a in attrs) {
      if (a is Map<String, dynamic>) {
        if (a['attribute_key'] == 'datas' && a['value'] is Map) {
          datas = a['value'] as Map<String, dynamic>;
        }
        if (a['attribute_key'] == 'plateNo') {
          plateNo = a['value']?.toString();
        }
      }
    }

    return VtrackingVehicle(
      id: (v['id'] ?? '').toString(),
      deviceId: (v['device_id'] ?? '').toString(),
      vehicleName: (v['vehicle_name'] ?? '').toString(),
      licensePlate: (v['license_plate'] ?? plateNo ?? '').toString(),
      latitude: _toDouble(datas['latitude']),
      longitude: _toDouble(datas['longitude']),
      speed: _toDouble(datas['speed']),
      status: (datas['status'] ?? 'unknown').toString(),
      geocoding: (datas['geocoding'] ?? '').toString(),
      direction: _toInt(datas['direction']),
      timestamp: _toInt(datas['timestamp']),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool get hasPosition => latitude != 0 && longitude != 0;
}
