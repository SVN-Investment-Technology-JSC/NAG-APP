// Fleet monitoring (CAN fuel + leftover concrete). Data comes from the fleet service through
// /api/v1/fleet-monitoring/* — every response is `{ statusCode, data }`.
// Mirrors src/types/fleet-monitoring.ts of the web frontend.

double? _d(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v);
  return null;
}

int? _i(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

String? _s(dynamic v) => v?.toString();

bool _b(dynamic v) => v == true;

Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<T> _l<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    v is List ? v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList() : <T>[];

List<double?> _nums(dynamic v) => v is List ? v.map(_d).toList() : <double?>[];

class FleetVehicle {
  final int? naVehicleId;
  final String fleetVehicleId;
  final String code;
  final String plate;
  final String? naName;
  final String? type;
  final bool concreteEnabled;
  final bool fuelEnabled;
  final double? tankCapacityL;

  FleetVehicle({
    this.naVehicleId,
    required this.fleetVehicleId,
    required this.code,
    required this.plate,
    this.naName,
    this.type,
    required this.concreteEnabled,
    required this.fuelEnabled,
    this.tankCapacityL,
  });

  String get displayName => naName ?? code;

  factory FleetVehicle.fromJson(Map<String, dynamic> j) => FleetVehicle(
        naVehicleId: _i(j['na_vehicle_id']),
        fleetVehicleId: _s(j['fleet_vehicle_id']) ?? '',
        code: _s(j['code']) ?? '',
        plate: _s(j['plate']) ?? '',
        naName: _s(j['na_name']),
        type: _s(j['type']),
        concreteEnabled: _b(j['concrete_enabled']),
        fuelEnabled: _b(j['fuel_enabled']),
        tankCapacityL: _d(j['tank_capacity_l']),
      );
}

class FuelSummary {
  final double? fuelUsedL;
  final String? fuelNote;
  final double? distanceKm;
  final double? lPer100km;
  final String? l100Kind;
  final double? lPer100kmTotal;
  final double? fuelMovingL;
  final double? fuelStandingL;
  final double? fuelUncertaintyL;
  final String? l100Reason;
  final double? engineHours;
  final double? idleHours;
  final double? movingHours;

  FuelSummary({
    this.fuelUsedL,
    this.fuelNote,
    this.distanceKm,
    this.lPer100km,
    this.l100Kind,
    this.lPer100kmTotal,
    this.fuelMovingL,
    this.fuelStandingL,
    this.fuelUncertaintyL,
    this.l100Reason,
    this.engineHours,
    this.idleHours,
    this.movingHours,
  });

  /// L/100 km of ALL the fuel burnt (driving + standing) over the distance.
  double? get l100 => lPer100kmTotal ?? lPer100km;

  factory FuelSummary.fromJson(Map<String, dynamic> j) => FuelSummary(
        fuelUsedL: _d(j['fuel_used_l']),
        fuelNote: _s(j['fuel_note']),
        distanceKm: _d(j['distance_km']),
        lPer100km: _d(j['l_per_100km']),
        l100Kind: _s(j['l100_kind']),
        lPer100kmTotal: _d(j['l_per_100km_total']),
        fuelMovingL: _d(j['fuel_moving_l']),
        fuelStandingL: _d(j['fuel_standing_l']),
        fuelUncertaintyL: _d(j['fuel_uncertainty_l']),
        l100Reason: _s(j['l100_reason']),
        engineHours: _d(j['engine_hours']),
        idleHours: _d(j['idle_hours']),
        movingHours: _d(j['moving_hours']),
      );
}

class FleetSignal {
  final String label;
  final String state; // ok | suspect | absent
  final String? reason;
  final int samples;

  FleetSignal({required this.label, required this.state, this.reason, required this.samples});

  factory FleetSignal.fromJson(Map<String, dynamic> j) => FleetSignal(
        label: _s(j['label']) ?? '',
        state: _s(j['state']) ?? 'absent',
        reason: _s(j['reason']),
        samples: _i(j['samples']) ?? 0,
      );
}

class FleetCapabilities {
  final Map<String, FleetSignal> signals;
  final String fuelLabel;
  final String distanceLabel;
  final String motionLabel;
  final String engineLabel;
  final List<String> suspect;

  FleetCapabilities({
    required this.signals,
    required this.fuelLabel,
    required this.distanceLabel,
    required this.motionLabel,
    required this.engineLabel,
    required this.suspect,
  });

  factory FleetCapabilities.fromJson(Map<String, dynamic> j) => FleetCapabilities(
        signals: _m(j['signals']).map((k, v) => MapEntry(k, FleetSignal.fromJson(_m(v)))),
        fuelLabel: _s(_m(j['fuel'])['label']) ?? '',
        distanceLabel: _s(_m(j['distance'])['label']) ?? '',
        motionLabel: _s(_m(j['motion'])['label']) ?? '',
        engineLabel: _s(_m(j['engine'])['label']) ?? '',
        suspect: j['suspect'] is List ? (j['suspect'] as List).map((e) => e.toString()).toList() : <String>[],
      );
}

class FleetSeriesEvent {
  final String id;
  final String type;
  final String severity;
  final String title;
  final int startTs;
  final int? endTs;
  final double? deltaPct;

  FleetSeriesEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.startTs,
    this.endTs,
    this.deltaPct,
  });

  factory FleetSeriesEvent.fromJson(Map<String, dynamic> j) => FleetSeriesEvent(
        id: _s(j['id']) ?? '',
        type: _s(j['type']) ?? '',
        severity: _s(j['severity']) ?? 'info',
        title: _s(j['title']) ?? '',
        startTs: _i(j['start_ts']) ?? 0,
        endTs: _i(j['end_ts']),
        deltaPct: _d(j['delta_pct']),
      );
}

class FleetSeries {
  final FleetCapabilities? capabilities;
  final int sourcesCan;
  final List<int> ts;
  final List<double?> levelRaw; // realtime CAN level, % (also while driving)
  final List<double?> levelFiltered;
  final List<double?> fuelRateLph;
  final List<double?> totalFuelL;
  final List<double?> rpm;
  final List<double?> speed;
  final List<double?> lat;
  final List<double?> lon;
  final List<double?>? odo;
  final FuelSummary summary;
  final List<FleetSeriesEvent> events;
  final double? tankCapacityL;

  FleetSeries({
    this.capabilities,
    required this.sourcesCan,
    required this.ts,
    this.levelRaw = const [],
    required this.levelFiltered,
    required this.fuelRateLph,
    required this.totalFuelL,
    required this.rpm,
    required this.speed,
    required this.lat,
    required this.lon,
    this.odo,
    required this.summary,
    required this.events,
    this.tankCapacityL,
  });

  factory FleetSeries.fromJson(Map<String, dynamic> j) {
    final s = _m(j['series']);
    return FleetSeries(
      capabilities: j['capabilities'] is Map ? FleetCapabilities.fromJson(_m(j['capabilities'])) : null,
      sourcesCan: _i(_m(j['sources'])['can']) ?? 0,
      ts: s['ts'] is List ? (s['ts'] as List).map((e) => _i(e) ?? 0).toList() : <int>[],
      levelRaw: _nums(s['level_raw']),
      levelFiltered: _nums(s['level_filtered']),
      fuelRateLph: _nums(s['fuel_rate_lph']),
      totalFuelL: _nums(s['total_fuel_l']),
      rpm: _nums(s['rpm']),
      speed: _nums(s['speed']),
      lat: _nums(s['lat']),
      lon: _nums(s['lon']),
      odo: s['odo'] is List ? _nums(s['odo']) : null,
      summary: FuelSummary.fromJson(_m(j['summary'])),
      events: _l(j['events'], FleetSeriesEvent.fromJson),
      tankCapacityL: _d(j['tank_capacity_l']),
    );
  }
}

class FleetRisk {
  final String level; // check | normal | delivery
  final bool main; // the trip's main delivery stop
  final String? note;
  final String? position;
  final String? reason;

  FleetRisk({required this.level, this.main = false, this.note, this.position, this.reason});

  factory FleetRisk.fromJson(Map<String, dynamic> j) => FleetRisk(
        level: _s(j['level']) ?? 'normal',
        main: _b(j['main']),
        note: _s(j['note']),
        position: _s(j['position']),
        reason: _s(j['reason']),
      );
}

class FleetMedia {
  final String id;
  final String kind;
  final String contentType;
  final String url;
  final String? capturedFrom;
  final String? capturedTo;

  FleetMedia({
    required this.id,
    required this.kind,
    required this.contentType,
    required this.url,
    this.capturedFrom,
    this.capturedTo,
  });

  factory FleetMedia.fromJson(Map<String, dynamic> j) => FleetMedia(
        id: _s(j['id']) ?? '',
        kind: _s(j['kind']) ?? '',
        contentType: _s(j['content_type']) ?? '',
        url: _s(j['url']) ?? '',
        capturedFrom: _s(j['captured_from']),
        capturedTo: _s(j['captured_to']),
      );
}

class FleetReview {
  final String id;
  final String label;
  final String note;
  final String ts;

  FleetReview({required this.id, required this.label, required this.note, required this.ts});

  factory FleetReview.fromJson(Map<String, dynamic> j) => FleetReview(
        id: _s(j['id']) ?? '',
        label: _s(j['label']) ?? '',
        note: _s(j['note']) ?? '',
        ts: _s(j['ts']) ?? '',
      );
}

class FleetEvent {
  final String id;
  final String code;
  final String vehicleId;
  final String vehicleCode;
  final String vehiclePlate;
  final String? tripId;
  final String category;
  final String type;
  final String startedAt;
  final String? endedAt;
  final double? lat;
  final double? lon;
  final double? durationS;
  final bool? engineOn;
  final String severity;
  final String title;
  final String reason;
  final String status;
  final String? reviewLabel;
  final Map<String, dynamic> evidence;
  final String? thumbUrl;
  final FleetRisk? risk;
  final String? address;

  // Detail-only fields
  final List<FleetMedia> media;
  final List<FleetReview> reviews;
  final List<String> cameraJobStatuses;
  final int cameraCount;

  FleetEvent({
    required this.id,
    required this.code,
    required this.vehicleId,
    required this.vehicleCode,
    required this.vehiclePlate,
    this.tripId,
    required this.category,
    required this.type,
    required this.startedAt,
    this.endedAt,
    this.lat,
    this.lon,
    this.durationS,
    this.engineOn,
    required this.severity,
    required this.title,
    required this.reason,
    required this.status,
    this.reviewLabel,
    required this.evidence,
    this.thumbUrl,
    this.risk,
    this.address,
    this.media = const [],
    this.reviews = const [],
    this.cameraJobStatuses = const [],
    this.cameraCount = 0,
  });

  factory FleetEvent.fromJson(Map<String, dynamic> j) => FleetEvent(
        id: _s(j['id']) ?? '',
        code: _s(j['code']) ?? '',
        vehicleId: _s(j['vehicle_id']) ?? '',
        vehicleCode: _s(j['vehicle_code']) ?? '',
        vehiclePlate: _s(j['vehicle_plate']) ?? '',
        tripId: _s(j['trip_id']),
        category: _s(j['category']) ?? '',
        type: _s(j['type']) ?? '',
        startedAt: _s(j['started_at']) ?? '',
        endedAt: _s(j['ended_at']),
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        durationS: _d(j['duration_s']),
        engineOn: j['engine_on'] is bool ? j['engine_on'] as bool : null,
        severity: _s(j['severity']) ?? 'info',
        title: _s(j['title']) ?? '',
        reason: _s(j['reason']) ?? '',
        status: _s(j['status']) ?? '',
        reviewLabel: _s(j['review_label']),
        evidence: _m(j['evidence']),
        thumbUrl: _s(j['thumb_url']),
        risk: j['risk'] is Map ? FleetRisk.fromJson(_m(j['risk'])) : null,
        address: _s(j['address']),
        media: _l(j['media'], FleetMedia.fromJson),
        reviews: _l(j['reviews'], FleetReview.fromJson),
        cameraJobStatuses:
            j['camera_jobs'] is List ? (j['camera_jobs'] as List).map((e) => _s(_m(e)['status']) ?? '').toList() : <String>[],
        cameraCount: j['cameras'] is List ? (j['cameras'] as List).length : 0,
      );
}

class FleetTripRisk {
  final int check;
  final int normal;
  final int delivery;
  final bool uncertain;

  FleetTripRisk({required this.check, required this.normal, required this.delivery, required this.uncertain});

  factory FleetTripRisk.fromJson(Map<String, dynamic> j) => FleetTripRisk(
        check: _i(j['check']) ?? 0,
        normal: _i(j['normal']) ?? 0,
        delivery: _i(j['delivery']) ?? 0,
        uncertain: _b(j['uncertain']),
      );
}

class FleetTrip {
  final String tripId;
  final int? orderNumber;
  final String purpose; // delivery | no_load
  final String status;
  final String startedAt;
  final String? endedAt;
  final FuelSummary fuel;
  final bool concreteChecked;
  final FleetTripRisk? risk;

  FleetTrip({
    required this.tripId,
    this.orderNumber,
    required this.purpose,
    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.fuel,
    required this.concreteChecked,
    this.risk,
  });

  factory FleetTrip.fromJson(Map<String, dynamic> j) {
    final c = _m(j['concrete']);
    return FleetTrip(
      tripId: _s(j['trip_id']) ?? '',
      orderNumber: _i(j['order_number']),
      purpose: _s(j['purpose']) ?? 'delivery',
      status: _s(j['status']) ?? '',
      startedAt: _s(j['started_at']) ?? '',
      endedAt: _s(j['ended_at']),
      fuel: FuelSummary.fromJson(_m(j['fuel'])),
      concreteChecked: _b(c['checked']),
      risk: c['risk'] is Map ? FleetTripRisk.fromJson(_m(c['risk'])) : null,
    );
  }
}

class FleetGeofence {
  final String id;
  final String name;
  final double? centerLat;
  final double? centerLon;
  final double? radiusM;
  final bool active;

  FleetGeofence({required this.id, required this.name, this.centerLat, this.centerLon, this.radiusM, required this.active});

  factory FleetGeofence.fromJson(Map<String, dynamic> j) => FleetGeofence(
        id: _s(j['id']) ?? '',
        name: _s(j['name']) ?? '',
        centerLat: _d(j['center_lat']),
        centerLon: _d(j['center_lon']),
        radiusM: _d(j['radius_m']),
        active: _b(j['active']),
      );
}

class FleetOverviewTrip {
  final String? tripId;
  final int? orderNumber;
  final String purpose;
  final String startedAt;

  FleetOverviewTrip({this.tripId, this.orderNumber, required this.purpose, required this.startedAt});

  factory FleetOverviewTrip.fromJson(Map<String, dynamic> j) => FleetOverviewTrip(
        tripId: _s(j['trip_id']),
        orderNumber: _i(j['order_number']),
        purpose: _s(j['purpose']) ?? 'delivery',
        startedAt: _s(j['started_at']) ?? '',
      );
}

class FleetOverviewVehicle {
  final String fleetVehicleId;
  final String code;
  final String plate;
  final String? naName;
  final String? type;
  final bool concreteEnabled;
  final double? tankCapacityL;
  final double? fuelLevelPct;
  final double? fuelLevelL;
  final bool hasCan;
  final String activity;
  final double? speedKmh;
  final double? dataAgeS;
  final double? lat;
  final double? lon;
  final double? heading;
  final String? address;
  final FleetOverviewTrip? trip;
  final int fuelAlerts;
  final int concreteAlerts;

  FleetOverviewVehicle({
    required this.fleetVehicleId,
    required this.code,
    required this.plate,
    this.naName,
    this.type,
    required this.concreteEnabled,
    this.tankCapacityL,
    this.fuelLevelPct,
    this.fuelLevelL,
    required this.hasCan,
    required this.activity,
    this.speedKmh,
    this.dataAgeS,
    this.lat,
    this.lon,
    this.heading,
    this.address,
    this.trip,
    required this.fuelAlerts,
    required this.concreteAlerts,
  });

  String get displayName => naName ?? code;

  factory FleetOverviewVehicle.fromJson(Map<String, dynamic> j) => FleetOverviewVehicle(
        fleetVehicleId: _s(j['fleet_vehicle_id']) ?? '',
        code: _s(j['code']) ?? '',
        plate: _s(j['plate']) ?? '',
        naName: _s(j['na_name']),
        type: _s(j['type']),
        concreteEnabled: _b(j['concrete_enabled']),
        tankCapacityL: _d(j['tank_capacity_l']),
        fuelLevelPct: _d(j['fuel_level_pct']),
        fuelLevelL: _d(j['fuel_level_l']),
        hasCan: _b(j['has_can']),
        activity: _s(j['activity']) ?? 'unknown',
        speedKmh: _d(j['speed_kmh']),
        dataAgeS: _d(j['data_age_s']),
        lat: _d(j['lat']),
        lon: _d(j['lon']),
        heading: _d(j['heading']),
        address: _s(j['address']),
        trip: j['trip'] is Map ? FleetOverviewTrip.fromJson(_m(j['trip'])) : null,
        fuelAlerts: _i(j['fuel_alerts']) ?? 0,
        concreteAlerts: _i(j['concrete_alerts']) ?? 0,
      );
}

class FleetAlert {
  final String id;
  final String category; // fuel | concrete
  final String severity;
  final String title;
  final String vehicleCode;
  final String startedAt;
  final double? durationS;
  final double? deltaPct;
  final double? dropL;
  final bool? discharge;
  final String? riskLevel;
  final String? riskReason;
  /// Already handled (only events of a past day can be; the live overview lists only open ones).
  final bool reviewed;

  FleetAlert({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.vehicleCode,
    required this.startedAt,
    this.durationS,
    this.deltaPct,
    this.dropL,
    this.discharge,
    this.riskLevel,
    this.riskReason,
    this.reviewed = false,
  });

  /// Same shape as an overview alert, built from an event of the events list (alerts of a chosen day).
  factory FleetAlert.fromEvent(FleetEvent e) => FleetAlert(
        id: e.id,
        category: e.category,
        severity: e.severity,
        title: e.title,
        vehicleCode: e.vehicleCode,
        startedAt: e.startedAt,
        durationS: e.durationS,
        deltaPct: _d(e.evidence['delta_pct']),
        dropL: _d(e.evidence['drop_l']),
        discharge: e.evidence['discharge_signature'] is bool ? e.evidence['discharge_signature'] as bool : null,
        riskLevel: e.category == 'concrete' ? e.risk?.level : null,
        riskReason: e.category == 'concrete' ? e.risk?.reason : null,
        reviewed: e.status == 'reviewed',
      );

  factory FleetAlert.fromJson(Map<String, dynamic> j) => FleetAlert(
        id: _s(j['id']) ?? '',
        category: _s(j['category']) ?? 'fuel',
        severity: _s(j['severity']) ?? 'info',
        title: _s(j['title']) ?? '',
        vehicleCode: _s(j['vehicle_code']) ?? '',
        startedAt: _s(j['started_at']) ?? '',
        durationS: _d(j['duration_s']),
        deltaPct: _d(j['delta_pct']),
        dropL: _d(j['drop_l']),
        discharge: j['discharge'] is bool ? j['discharge'] as bool : null,
        riskLevel: _s(j['risk_level']),
        riskReason: _s(j['risk_reason']),
      );
}

class FleetOverviewTotals {
  final int vehicles;
  final int withCan;
  final int fuelAlerts;
  final int concreteAlerts;
  final int noTankSize;

  FleetOverviewTotals({
    required this.vehicles,
    required this.withCan,
    required this.fuelAlerts,
    required this.concreteAlerts,
    required this.noTankSize,
  });

  factory FleetOverviewTotals.fromJson(Map<String, dynamic> j) => FleetOverviewTotals(
        vehicles: _i(j['vehicles']) ?? 0,
        withCan: _i(j['with_can']) ?? 0,
        fuelAlerts: _i(j['fuel_alerts']) ?? 0,
        concreteAlerts: _i(j['concrete_alerts']) ?? 0,
        noTankSize: _i(j['no_tank_size']) ?? 0,
      );
}

class FleetOverview {
  final List<FleetOverviewVehicle> vehicles;
  final List<FleetAlert> alerts;
  final FleetOverviewTotals totals;

  FleetOverview({required this.vehicles, required this.alerts, required this.totals});

  factory FleetOverview.fromJson(Map<String, dynamic> j) => FleetOverview(
        vehicles: _l(j['vehicles'], FleetOverviewVehicle.fromJson),
        alerts: _l(j['alerts'], FleetAlert.fromJson),
        totals: FleetOverviewTotals.fromJson(_m(j['totals'])),
      );
}

class FuelSummaryResult {
  final FuelSummary? total;
  final bool partial;

  FuelSummaryResult({this.total, required this.partial});
}
