import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_common.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_event_sheet.dart';

/// "Bê tông thừa" — port of ConcreteMonitor.tsx: per mixer truck and day, its trips, the route of one trip and its stops.
class FleetConcreteTab extends StatefulWidget {
  final FleetPermissions perms;
  final ValueNotifier<String?> request;

  const FleetConcreteTab({super.key, required this.perms, required this.request});

  @override
  State<FleetConcreteTab> createState() => _FleetConcreteTabState();
}

class _FleetConcreteTabState extends State<FleetConcreteTab> with AutomaticKeepAliveClientMixin {
  static const _storeKey = 'fleet-concrete-vehicle';

  final _api = FleetMonitoringService();
  List<FleetVehicle> _vehicles = [];
  String? _vid;
  DateTime _day = DateTime.now();
  List<FleetTrip> _trips = [];
  List<FleetEvent> _events = [];
  List<FleetGeofence> _yards = [];
  List<LatLng> _route = [];
  List<int> _routeTs = [];
  String? _tripId;
  bool _showNormal = false;
  bool _loading = false;
  bool _routeLoading = false;
  String? _error;
  int _seq = 0;
  int _routeSeq = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.request.addListener(_onRequest);
    _init();
  }

  @override
  void dispose() {
    widget.request.removeListener(_onRequest);
    super.dispose();
  }

  void _onRequest() {
    final id = widget.request.value;
    if (id == null) return;
    widget.request.value = null;
    if (_vehicles.any((v) => v.fleetVehicleId == id)) _setVehicle(id);
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    _api.geofences().then((g) {
      if (mounted) setState(() => _yards = g);
    }).catchError((_) {});
    try {
      final vs = (await _api.vehicles()).where((v) => v.concreteEnabled).toList();
      final prefs = await SharedPreferences.getInstance();
      final asked = widget.request.value;
      widget.request.value = null;
      final saved = asked ?? prefs.getString(_storeKey);
      if (!mounted) return;
      setState(() {
        _vehicles = vs;
        _vid = vs.where((v) => v.fleetVehicleId == saved).firstOrNull?.fleetVehicleId ?? vs.firstOrNull?.fleetVehicleId;
      });
      _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được danh sách xe bồn';
        });
      }
    }
  }

  void _setVehicle(String id) {
    setState(() => _vid = id);
    SharedPreferences.getInstance().then((p) => p.setString(_storeKey, id));
    _load();
  }

  Future<void> _load() async {
    final vid = _vid;
    if (vid == null) {
      setState(() => _loading = false);
      return;
    }
    final r = dayRange(_day);
    final seq = ++_seq;
    setState(() {
      _loading = true;
    });
    try {
      final res = await Future.wait([
        _api.trips(vid, r.from, r.to),
        _api.concreteEvents(vehicleId: vid, from: r.from, to: r.to, limit: 200),
      ]);
      if (!mounted || seq != _seq) return;
      final trips = res[0] as List<FleetTrip>;
      final events = (res[1] as List<FleetEvent>)..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      setState(() {
        _trips = trips;
        _events = events;
        _error = null;
        // keep the selected trip if it is still there; else the latest trip with stops to check, else the latest one
        if (!trips.any((t) => t.tripId == _tripId)) _tripId = _defaultTrip(trips)?.tripId;
      });
      _loadRoute();
    } catch (_) {
      if (mounted && seq == _seq) setState(() => _error = 'Không tải được dữ liệu bê tông thừa');
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  FleetTrip? _defaultTrip(List<FleetTrip> trips) {
    if (trips.isEmpty) return null;
    FleetTrip latest(Iterable<FleetTrip> xs) => xs.reduce((a, b) => a.startedAt.compareTo(b.startedAt) >= 0 ? a : b);
    final flagged = trips.where((t) => (t.risk?.check ?? 0) > 0);
    return flagged.isNotEmpty ? latest(flagged) : latest(trips);
  }

  FleetTrip? get _trip => _trips.where((t) => t.tripId == _tripId).firstOrNull;

  Future<void> _loadRoute() async {
    final vid = _vid, trip = _trip;
    final seq = ++_routeSeq;
    if (vid == null || trip == null) {
      setState(() {
        _route = [];
        _routeTs = [];
      });
      return;
    }
    final start = parseTime(trip.startedAt);
    if (start == null) return;
    final end = parseTime(trip.endedAt) ?? DateTime.now();
    setState(() => _routeLoading = true);
    try {
      final s = await _api.routeSeries(vid, toUnix(start) - 120, toUnix(end) + 120);
      if (!mounted || seq != _routeSeq) return;
      final pts = <LatLng>[];
      final tss = <int>[];
      for (var i = 0; i < s.ts.length; i++) {
        final la = i < s.lat.length ? s.lat[i] : null, lo = i < s.lon.length ? s.lon[i] : null;
        if (la != null && lo != null) {
          pts.add(LatLng(la, lo));
          tss.add(s.ts[i]);
        }
      }
      setState(() {
        _route = pts;
        _routeTs = tss;
      });
    } catch (_) {
      if (mounted && seq == _routeSeq) {
        setState(() {
          _route = [];
          _routeTs = [];
        });
      }
    } finally {
      if (mounted && seq == _routeSeq) setState(() => _routeLoading = false);
    }
  }

  void _selectTrip(String id) {
    setState(() => _tripId = id);
    _loadRoute();
  }

  List<FleetEvent> get _tripEvents => _trip == null ? [] : _events.where((e) => e.tripId == _trip!.tripId).toList();

  /// "Cần kiểm tra" first, then the delivery, the normal ones only when unfolded.
  List<FleetEvent> get _shown {
    int rank(FleetEvent e) => e.risk == null || e.risk!.level == 'check'
        ? 0
        : e.risk!.level == 'delivery'
            ? 1
            : 2;
    final list = _tripEvents.where((e) => _showNormal || rank(e) < 2).toList()
      ..sort((a, b) {
        final r = rank(a) - rank(b);
        return r != 0 ? r : a.startedAt.compareTo(b.startedAt);
      });
    return list;
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDate: _day);
    if (d == null) return;
    setState(() => _day = d);
    _load();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final yday = now.subtract(const Duration(days: 1));
    final dayKey = _sameDay(_day, now)
        ? 'today'
        : _sameDay(_day, yday)
            ? 'yday'
            : 'other';
    final deliveries = _trips.where((t) => t.purpose == 'delivery').length;
    final flagged = _events.where((e) => e.risk?.level == 'check').length;
    final discharges = _events.where((e) => e.evidence['discharge_signature'] == true).length;
    final trip = _trip;
    final idx = trip == null ? -1 : _trips.indexOf(trip);
    final normalCount = _tripEvents.where((e) => e.risk?.level == 'normal').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          VehiclePickerField(vehicles: _vehicles, selectedId: _vid, onChanged: _setVehicle, emptyText: 'Không có xe bồn'),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: SegmentChips<String>(
                  options: const [('today', 'Hôm nay'), ('yday', 'Hôm qua')],
                  value: dayKey,
                  onChanged: (v) {
                    setState(() => _day = v == 'today' ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1)));
                    _load();
                  },
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_rounded, size: 15),
                label: Text(DateFormat('dd/MM/yyyy').format(_day), style: TextStyle(fontSize: 12.sp)),
                visualDensity: VisualDensity.compact,
                backgroundColor: dayKey == 'other' ? cs.secondaryContainer : null,
                onPressed: _pickDay,
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2) else SizedBox(height: 2.h),
          SizedBox(height: 10.h),
          if (_error != null) FleetNotice(_error!, color: const Color(0xFFDC2626)),
          Text('Chỉ áp dụng cho xe bồn · theo chuyến giao hàng · không kiểm tra trong bãi/trạm',
              style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
          SizedBox(height: 8.h),
          KpiGrid(children: [
            KpiTile(icon: Icons.route_rounded, label: 'Chuyến giao hàng', value: '$deliveries', color: const Color(0xFF2563EB)),
            KpiTile(icon: Icons.place_outlined, label: 'Chuyến không lấy hàng', value: '${_trips.length - deliveries}', color: const Color(0xFF64748B)),
            KpiTile(icon: Icons.warning_amber_rounded, label: 'Lần dừng cần kiểm tra', value: '$flagged', color: const Color(0xFFDC2626)),
            KpiTile(icon: Icons.speed_rounded, label: 'Lần xả theo vòng tua', value: '$discharges', color: const Color(0xFFD97706)),
          ]),
          FleetSection(
            title: 'Chuyến trong ngày',
            trailing: Text('Bấm để xem lộ trình', style: TextStyle(fontSize: 10.sp, color: cs.outline)),
            child: _trips.isEmpty ? const FleetEmpty('Không có chuyến trong ngày') : Column(children: [for (final t in _trips) _tripRow(t)]),
          ),
          FleetSection(
            padding: EdgeInsets.all(8.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Chuyến trước',
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: idx < 0 || idx >= _trips.length - 1 ? null : () => _selectTrip(_trips[idx + 1].tripId),
                    ),
                    Expanded(
                      child: Text(
                        trip != null
                            ? 'Lộ trình chuyến #${trip.orderNumber ?? ''} (${fmtTime(trip.startedAt)} → ${trip.endedAt != null ? fmtTime(trip.endedAt) : 'đang chạy'})'
                            : 'Lộ trình chuyến',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Chuyến sau',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: idx <= 0 ? null : () => _selectTrip(_trips[idx - 1].tripId),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  alignment: WrapAlignment.center,
                  children: [
                    _legendLine(kRouteGo, 'Chiều đi'),
                    _legendLine(kRouteBack, 'Chiều về'),
                    for (final k in const ['check', 'delivery', 'normal']) _legendDot(riskOf(k).color, riskOf(k).label),
                  ],
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  height: 320.h,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _routeMap()),
                      if (_routeLoading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text('Điểm dừng', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                ),
                SizedBox(height: 4.h),
                if (_shown.isEmpty)
                  FleetEmpty(trip != null ? 'Chuyến này không có lần dừng nào được ghi nhận' : 'Chọn một chuyến để xem'),
                for (var i = 0; i < _shown.length; i++) _stopRow(_shown[i], i),
                if (normalCount > 0)
                  TextButton(
                    onPressed: () => setState(() => _showNormal = !_showNormal),
                    child: Text('${_showNormal ? 'Ẩn' : 'Xem'} $normalCount lần dừng bình thường (dưới ngưỡng, hoặc tắt máy)'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendLine(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 16, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.sp)),
      ]);

  Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.sp)),
      ]);

  Widget _tripRow(FleetTrip t) {
    final cs = Theme.of(context).colorScheme;
    final sel = t.tripId == _tripId;
    final check = t.risk?.check ?? 0;
    return InkWell(
      onTap: () => _selectTrip(t.tripId),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: sel ? cs.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: sel ? cs.primary.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('#${t.orderNumber ?? '—'}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800)),
                      ToneChip(
                        label: t.purpose == 'delivery' ? 'Giao hàng' : 'Không lấy hàng',
                        color: t.purpose == 'delivery' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        dense: true,
                      ),
                      if (t.endedAt == null) const ToneChip(label: 'đang chạy', color: Color(0xFF0EA5E9), dense: true),
                      if (t.risk?.uncertain == true) const ToneChip(label: 'chưa rõ điểm giao', color: Color(0xFFDC2626), dense: true),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${fmtTime(t.startedAt)} → ${t.endedAt != null ? fmtTime(t.endedAt) : '…'}  ·  Dầu ${fmtNum(t.fuel.fuelUsedL, 1, 'L')}',
                    style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (!t.concreteChecked)
              Text('không kiểm tra', style: TextStyle(fontSize: 10.sp, color: cs.outline))
            else
              Column(
                children: [
                  Text('$check',
                      style: TextStyle(
                          fontSize: 16.sp, fontWeight: FontWeight.w900, color: check > 0 ? const Color(0xFFDC2626) : cs.outline)),
                  Text('cần KT', style: TextStyle(fontSize: 9.sp, color: cs.outline)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _stopRow(FleetEvent e, int i) {
    final cs = Theme.of(context).colorScheme;
    final tone = e.risk != null ? riskOf(e.risk!.level) : severityOf(e.severity);
    final delivery = e.risk?.level == 'delivery';
    final reason = e.risk?.reason ?? e.risk?.note;
    return InkWell(
      onTap: () => _openEvent(e.id),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone.color, shape: BoxShape.circle),
              child: delivery
                  ? const Icon(Icons.flag_rounded, size: 15, color: Colors.white)
                  : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fmtTime(e.startedAt)} · ${fmtDur(e.durationS)}${e.risk != null ? '' : ' — ${e.title}'}'
                    '${e.risk?.position != null ? ' · ${e.risk!.position!.toLowerCase()}' : ''}',
                    style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                  ),
                  if (reason != null && reason.isNotEmpty) Text(reason, style: TextStyle(fontSize: 11.5.sp, color: cs.onSurface)),
                  if (e.address != null && e.address!.isNotEmpty)
                    Text(e.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: cs.outline)),
                ],
              ),
            ),
            SizedBox(width: 6.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ToneChip(label: tone.label, color: tone.color, dense: true),
                if (e.thumbUrl != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4.h),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: Image.network(
                        FleetMonitoringService.mediaUrl(e.thumbUrl!),
                        width: 56.w,
                        height: 40.w,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEvent(String id) => showFleetEventSheet(
        context,
        eventId: id,
        category: 'concrete',
        cameraAllowed: widget.perms.concreteReview,
        onChanged: _load,
      );

  /// Outbound until the truck leaves the delivery place (its last delivery stop ends), return after that.
  /// Without a delivery stop: split at the point farthest from the start.
  (List<LatLng>, List<LatLng>) _splitRoute() {
    if (_route.length < 2) return (_route, const []);
    var split = -1;
    final ends = _tripEvents
        .where((s) => s.risk?.level == 'delivery')
        .map((s) => parseTime(s.endedAt ?? s.startedAt))
        .whereType<DateTime>()
        .map(toUnix)
        .toList();
    if (ends.isNotEmpty) {
      final t = ends.reduce((a, b) => a > b ? a : b);
      split = _routeTs.indexWhere((x) => x >= t);
      if (split < 0) split = _route.length - 1;
    } else {
      const dist = Distance();
      var far = -1.0;
      for (var i = 0; i < _route.length; i++) {
        final d = dist(_route.first, _route[i]);
        if (d > far) {
          far = d;
          split = i;
        }
      }
    }
    return (_route.sublist(0, split + 1), _route.sublist(split));
  }

  Widget _routeMap() {
    final stops = _shown.where((e) => e.lat != null && e.lon != null).toList();
    final all = [..._route, ...stops.map((e) => LatLng(e.lat!, e.lon!))];
    if (all.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: FleetEmpty(_trip == null ? 'Chọn một chuyến để xem' : 'Chưa có dữ liệu vị trí', icon: Icons.map_outlined),
      );
    }
    final (go, back) = _splitRoute();
    final vehicle = _vehicles.where((v) => v.fleetVehicleId == _vid).firstOrNull;
    final fit = all.length > 1
        ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(all), padding: const EdgeInsets.all(30), maxZoom: 16)
        : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: FlutterMap(
        key: ValueKey('${_vid}_${_tripId}_${_route.length}_${stops.length}'),
        options: MapOptions(initialCameraFit: fit, initialCenter: all.first, initialZoom: 15),
        children: [
          TileLayer(
            urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.nguyenanh.nagapp',
          ),
          CircleLayer(circles: [
            for (final y in _yards)
              if (y.active && y.centerLat != null && y.centerLon != null && y.radiusM != null)
                CircleMarker(
                  point: LatLng(y.centerLat!, y.centerLon!),
                  radius: y.radiusM!,
                  useRadiusInMeter: true,
                  color: const Color(0xFF64748B).withValues(alpha: 0.12),
                  borderColor: const Color(0xFF64748B),
                  borderStrokeWidth: 1,
                ),
          ]),
          PolylineLayer(polylines: [
            if (go.length > 1) Polyline(points: go, color: kRouteGo, strokeWidth: 4, borderColor: Colors.white, borderStrokeWidth: 1.5),
            if (back.length > 1)
              Polyline(points: back, color: kRouteBack, strokeWidth: 4, borderColor: Colors.white, borderStrokeWidth: 1.5),
          ]),
          MarkerLayer(markers: [
            if (_route.isNotEmpty)
              Marker(
                point: _route.last,
                width: 110,
                height: 46,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 2),
                      ]),
                      child: Text(vehicle?.displayName ?? '',
                          maxLines: 1, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.black87)),
                    ),
                    const Icon(Icons.local_shipping_rounded, size: 22, color: Color(0xFF1E3A8A)),
                  ],
                ),
              ),
            for (final s in stops)
              Marker(
                point: LatLng(s.lat!, s.lon!),
                width: 30,
                height: 30,
                child: Builder(builder: (_) {
                  final delivery = s.risk?.level == 'delivery';
                  final c = s.risk != null ? riskOf(s.risk!.level).color : severityOf(s.severity).color;
                  return GestureDetector(
                    onTap: () => _openEvent(s.id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                      ),
                      child: delivery
                          ? const Icon(Icons.flag_rounded, size: 15, color: Colors.white)
                          : Text('${_shown.indexOf(s) + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  );
                }),
              ),
          ]),
        ],
      ),
    );
  }
}
