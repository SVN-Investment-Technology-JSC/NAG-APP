
class Station {
  final int stationId;
  final String stationName;
  final String stationAddress;
  final String stationGps;
  final double? stationGpsLatitude;
  final double? stationGpsLongitude;
  final int stationGpsGeofencing;
  final String? stationStatus;
  final String? stationDescription;
  final int stationTypeId;
  final String? stationTypeName;

  Station({
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.stationGps,
    this.stationGpsLatitude,
    this.stationGpsLongitude,
    required this.stationGpsGeofencing,
    this.stationStatus,
    this.stationDescription,
    required this.stationTypeId,
    this.stationTypeName,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      stationId: json['station_id'] ?? 0,
      stationName: json['station_name'] ?? '',
      stationAddress: json['station_address'] ?? '',
      stationGps: json['station_gps'] ?? '',
      stationGpsLatitude: (json['station_gps_latitude'] as num?)?.toDouble(),
      stationGpsLongitude: (json['station_gps_longitude'] as num?)?.toDouble(),
      stationGpsGeofencing: int.tryParse(json['station_gps_geofencing'].toString()) ?? 200,
      stationStatus: json['station_status'],
      stationDescription: json['station_description'],
      stationTypeId: json['station_type_id'] ?? json['station_types']?['station_type_id'] ?? 1,
      stationTypeName: json['station_types'] != null ? json['station_types']['station_type_name'] : null,
    );
  }

  // Latitude: prefer explicit field, fallback to parsing station_gps
  double? get getLat {
    if (stationGpsLatitude != null) return stationGpsLatitude;
    if (stationGps.isEmpty) return null;
    final parts = stationGps.split(',');
    if (parts.length > 1) {
      return double.tryParse(parts[0].trim());
    }
    return null;
  }

  // Longitude: prefer explicit field, fallback to parsing station_gps
  double? get getLng {
    if (stationGpsLongitude != null) return stationGpsLongitude;
    if (stationGps.isEmpty) return null;
    final parts = stationGps.split(',');
    if (parts.length > 1) {
      return double.tryParse(parts[1].trim());
    }
    return null;
  }
}
