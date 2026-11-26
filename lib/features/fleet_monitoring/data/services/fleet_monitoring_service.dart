import 'package:dio/dio.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/app_endpoints.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';

/// Fleet monitoring API (proxied by the backend to the fleet service).
/// Same endpoints as src/services/fleet-monitoring.service.ts of the web frontend.
class FleetMonitoringService {
  // Long ranges are computed on the server: give them more time than the 10 s default.
  static final Options _slow = Options(receiveTimeout: const Duration(seconds: 45));

  dynamic _unwrap(Response r) {
    final body = r.data;
    if (body is Map && body.containsKey('data')) return body['data'];
    return body;
  }

  Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<Map<String, dynamic>> _items(dynamic v) {
    final list = v is Map ? v['items'] : v;
    return list is List ? list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  }

  Future<List<FleetVehicle>> vehicles() async {
    final r = await ApiClient.dio.get('/fleet-monitoring/vehicles');
    final data = _unwrap(r);
    return data is List
        ? data.whereType<Map>().map((e) => FleetVehicle.fromJson(Map<String, dynamic>.from(e))).toList()
        : <FleetVehicle>[];
  }

  Future<FleetOverview> overview({int fuelDays = 7}) async {
    final r = await ApiClient.dio.get('/fleet-monitoring/overview', queryParameters: {'fuel_days': fuelDays}, options: _slow);
    return FleetOverview.fromJson(_map(_unwrap(r)));
  }

  /// Alerts of one calendar day [day] (local time), same rules as the overview's alerts but including the ones
  /// already handled: fuel drops "notable/strong", concrete stops the stop check marks "check" (old severity rule
  /// while not scored yet). Each category is asked only when [fuel]/[concrete] is true (needs that page permission);
  /// a category that fails is listed in [DayAlerts.failed] instead of failing the whole day.
  Future<DayAlerts> dayAlerts(DateTime day, {required bool fuel, required bool concrete}) async {
    final from = toUnixLocal(DateTime(day.year, day.month, day.day));
    final to = toUnixLocal(DateTime(day.year, day.month, day.day, 23, 59, 59));
    Future<List<FleetEvent>> all(String path) async {
      final out = <FleetEvent>[];
      for (var offset = 0; offset < 2000; offset += 500) {
        final r = await ApiClient.dio.get(path,
            queryParameters: {'from': from, 'to': to, 'limit': 500, 'offset': offset}, options: _slow);
        final page = _items(_unwrap(r)).map(FleetEvent.fromJson).toList();
        out.addAll(page);
        if (page.length < 500) break;
      }
      return out;
    }

    final failed = <String>[];
    final res = await Future.wait([
      fuel ? all('/fleet-monitoring/fuel/events').catchError((_) { failed.add('fuel'); return <FleetEvent>[]; }) : Future.value(<FleetEvent>[]),
      concrete ? all('/fleet-monitoring/concrete/events').catchError((_) { failed.add('concrete'); return <FleetEvent>[]; }) : Future.value(<FleetEvent>[]),
    ]);
    final alerts = <FleetAlert>[
      for (final e in res[0])
        if (e.type == 'fuel_drop' && (e.severity == 'notable' || e.severity == 'strong')) FleetAlert.fromEvent(e),
      for (final e in res[1])
        if (e.risk != null ? e.risk!.level == 'check' : (e.severity == 'suspect' || e.severity == 'review')) FleetAlert.fromEvent(e),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return DayAlerts(alerts, failed);
  }

  static int toUnixLocal(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

  /* ── Fuel ─────────────────────────────────────────────────────────────── */

  Future<FleetSeries> fuelSeries(String vehicleId, int from, int to, {int maxPoints = 1500}) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/fuel/vehicles/$vehicleId/series',
      queryParameters: {'from': from, 'to': to, 'max_points': maxPoints},
      options: _slow,
    );
    return FleetSeries.fromJson(_map(_unwrap(r)));
  }

  Future<FuelSummaryResult> fuelSummaryTotal(String vehicleId, int from, int to) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/fuel/vehicles/$vehicleId/summary',
      queryParameters: {'from': from, 'to': to, 'group': 'total'},
      options: _slow,
    );
    final d = _map(_unwrap(r));
    return FuelSummaryResult(
      total: d['total'] is Map ? FuelSummary.fromJson(_map(d['total'])) : null,
      partial: d['partial'] == true,
    );
  }

  Future<List<FleetEvent>> fuelEvents({required String vehicleId, required int from, required int to, int limit = 100}) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/fuel/events',
      queryParameters: {'vehicle_id': vehicleId, 'from': from, 'to': to, 'limit': limit},
      options: _slow,
    );
    return _items(_unwrap(r)).map(FleetEvent.fromJson).toList();
  }

  Future<FleetEvent> fuelEvent(String id) async {
    final r = await ApiClient.dio.get('/fleet-monitoring/fuel/events/$id');
    return FleetEvent.fromJson(_map(_unwrap(r)));
  }

  /* ── Leftover concrete ─────────────────────────────────────────────────── */

  Future<List<FleetTrip>> trips(String vehicleId, int from, int to) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/concrete/trips',
      queryParameters: {'fleet_vehicle_id': vehicleId, 'from': from, 'to': to},
      options: _slow,
    );
    return _items(_unwrap(r)).map(FleetTrip.fromJson).toList();
  }

  Future<FleetSeries> routeSeries(String vehicleId, int from, int to) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/concrete/vehicles/$vehicleId/series',
      queryParameters: {'from': from, 'to': to, 'max_points': 2500},
      options: _slow,
    );
    return FleetSeries.fromJson(_map(_unwrap(r)));
  }

  Future<List<FleetEvent>> concreteEvents({required String vehicleId, required int from, required int to, int limit = 200}) async {
    final r = await ApiClient.dio.get(
      '/fleet-monitoring/concrete/events',
      queryParameters: {'vehicle_id': vehicleId, 'from': from, 'to': to, 'limit': limit, 'rich': true},
      options: _slow,
    );
    return _items(_unwrap(r)).map(FleetEvent.fromJson).toList();
  }

  Future<FleetEvent> concreteEvent(String id) async {
    final r = await ApiClient.dio.get('/fleet-monitoring/concrete/events/$id');
    return FleetEvent.fromJson(_map(_unwrap(r)));
  }

  Future<List<FleetGeofence>> geofences() async {
    final r = await ApiClient.dio.get('/fleet-monitoring/concrete/geofences');
    final data = _unwrap(r);
    return data is List
        ? data.whereType<Map>().map((e) => FleetGeofence.fromJson(Map<String, dynamic>.from(e))).toList()
        : <FleetGeofence>[];
  }

  /// kind: snapshot | frame | clip
  Future<void> cameraJob(String eventId, String kind) async {
    await ApiClient.dio.post('/fleet-monitoring/concrete/events/$eventId/camera-jobs', data: {'kind': kind});
  }

  /// Camera media links come back as "/fleet-monitoring/media/<id>/file?exp&sig": make them absolute.
  static String mediaUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = AppEndpoints.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base${path.startsWith('/') ? path : '/$path'}';
  }
}

/// Alerts of one day, newest first; [failed] = categories that could not be loaded ('fuel' / 'concrete').
class DayAlerts {
  final List<FleetAlert> alerts;
  final List<String> failed;
  const DayAlerts(this.alerts, this.failed);
}
