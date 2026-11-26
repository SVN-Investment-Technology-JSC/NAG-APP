import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_reads.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_alert_day.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_event_sheet.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_trip_route_map.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// "Tổng quan" (v2). Same data and refresh rule as v1 (overview every 30 s), new layout.
class FxOverviewTab extends StatefulWidget {
  final FleetPermissions perms;
  final ValueChanged<String>? onOpenFuel;
  final ValueChanged<String>? onOpenConcrete;

  const FxOverviewTab({super.key, required this.perms, this.onOpenFuel, this.onOpenConcrete});

  @override
  State<FxOverviewTab> createState() => _FxOverviewTabState();
}

class _FxOverviewTabState extends State<FxOverviewTab> with AutomaticKeepAliveClientMixin {
  static const _alertsPerPage = 5;
  static const _vehiclesPerPage = 8;

  final _api = FleetMonitoringService();
  final _map = MapController();
  FleetOverview? _data;
  DateTime? _updatedAt;
  bool _loading = false;
  String? _error;
  String _q = '';
  String _only = 'all';
  String? _selected;
  int _alertPage = 0;
  int _vehPage = 0;
  Timer? _timer;
  // Alerts card: open alerts now (default) or every alert of a chosen day
  late final FleetAlertDay _day = FleetAlertDay(widget.perms)
    ..addListener(() {
      if (mounted) setState(() => _alertPage = 0);
    });

  // Route of the selected vehicle's current trip (go / back lanes + abnormal points), as on the web trip map.
  String? _routeVid;
  FleetTrip? _rTrip;
  List<LatLng> _rRoute = [];
  List<int> _rTs = [];
  List<FleetEvent> _rStops = [];
  List<FleetGeofence> _yards = [];
  bool _rLoading = false;
  int _rSeq = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
    FleetReads.instance.addListener(_readsChanged);
  }

  void _readsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    FleetReads.instance.removeListener(_readsChanged);
    _day.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final d = await _api.overview(fuelDays: 7);
      if (!mounted) return;
      setState(() {
        _data = d;
        _updatedAt = DateTime.now();
        _error = null;
      });
      FleetReads.instance.lookup(d.alerts.map((a) => a.id));
    } catch (_) {
      if (mounted && !quiet) setState(() => _error = 'Không tải được dữ liệu giám sát xe');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FleetOverviewVehicle> _filtered(String only) {
    final ql = _q.trim().toLowerCase();
    return (_data?.vehicles ?? []).where((v) {
      if (ql.isNotEmpty && !'${v.naName ?? ''} ${v.code} ${v.plate}'.toLowerCase().contains(ql)) return false;
      if (only == 'alert') return v.fuelAlerts + v.concreteAlerts > 0;
      if (only == 'can') return v.hasCan;
      return true;
    }).toList();
  }

  void _focus(FleetOverviewVehicle v) {
    setState(() => _selected = v.fleetVehicleId);
    if (v.trip?.tripId != null) {
      _loadRoute(v);
      return;
    }
    _closeRoute();
    if (v.lat != null && v.lon != null) {
      try {
        _map.move(LatLng(v.lat!, v.lon!), 15);
      } catch (_) {}
    }
  }

  void _closeRoute() {
    _rSeq++;
    if (_routeVid == null && !_rLoading) return;
    setState(() {
      _routeVid = null;
      _rTrip = null;
      _rRoute = [];
      _rTs = [];
      _rStops = [];
      _rLoading = false;
    });
  }

  /// Current trip of [v]: route series + concrete stops (mixer trucks) + fuel events with a position.
  Future<void> _loadRoute(FleetOverviewVehicle v) async {
    final seq = ++_rSeq;
    final start = parseTime(v.trip!.startedAt) ?? DateTime.now().subtract(const Duration(hours: 6));
    setState(() {
      _routeVid = v.fleetVehicleId;
      _rLoading = true;
      _rTrip = null;
      _rRoute = [];
      _rTs = [];
      _rStops = [];
    });
    if (_yards.isEmpty) {
      _api.geofences().then((g) {
        if (mounted) setState(() => _yards = g);
      }).catchError((_) {});
    }
    try {
      final now = toUnix(DateTime.now());
      final trips = await _api.trips(v.fleetVehicleId, toUnix(start) - 12 * 3600, now + 3600);
      final tr = trips.where((x) => x.tripId == v.trip!.tripId).firstOrNull;
      final from = toUnix(parseTime(tr?.startedAt) ?? start) - 120;
      final to = (tr?.endedAt != null ? toUnix(parseTime(tr!.endedAt)!) : now) + 120;
      final res = await Future.wait([
        _api.routeSeries(v.fleetVehicleId, from, to),
        v.concreteEnabled
            ? _api.concreteEvents(vehicleId: v.fleetVehicleId, from: from, to: to, limit: 200).catchError((_) => <FleetEvent>[])
            : Future.value(<FleetEvent>[]),
        _api.fuelEvents(vehicleId: v.fleetVehicleId, from: from, to: to, limit: 100).catchError((_) => <FleetEvent>[]),
      ]);
      if (!mounted || seq != _rSeq) return;
      final s = res[0] as FleetSeries;
      final pts = <LatLng>[];
      final tss = <int>[];
      for (var i = 0; i < s.ts.length; i++) {
        final la = i < s.lat.length ? s.lat[i] : null, lo = i < s.lon.length ? s.lon[i] : null;
        if (la != null && lo != null) {
          pts.add(LatLng(la, lo));
          tss.add(s.ts[i]);
        }
      }
      final concrete = (res[1] as List<FleetEvent>).where((e) => e.tripId == v.trip!.tripId || e.tripId == null).toList();
      final fuel = (res[2] as List<FleetEvent>).where((e) => e.lat != null && e.lon != null).toList();
      // "Cần kiểm tra" first, then the delivery, the normal stops last (same order as the Bê tông thừa list)
      int rank(FleetEvent e) => e.category == 'fuel' || e.risk == null || e.risk!.level == 'check' ? 0 : (e.risk!.level == 'delivery' ? 1 : 2);
      final stops = [...concrete, ...fuel]..sort((a, b) {
          final r = rank(a) - rank(b);
          return r != 0 ? r : a.startedAt.compareTo(b.startedAt);
        });
      setState(() {
        _rTrip = tr;
        _rRoute = pts;
        _rTs = tss;
        _rStops = stops;
      });
    } catch (_) {
      if (mounted && seq == _rSeq) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tải được lộ trình chuyến')));
      }
    } finally {
      if (mounted && seq == _rSeq) setState(() => _rLoading = false);
    }
  }

  void _openStop(String id) {
    final e = _rStops.where((x) => x.id == id).firstOrNull;
    if (e == null) return;
    showFxEventSheet(context, eventId: id, category: e.category == 'fuel' ? 'fuel' : 'concrete', cameraAllowed: widget.perms.concreteReview);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = FxTokens.of(context);
    if (_data == null && _loading) return const FxLoadingView();
    if (_data == null && _error != null) {
      return FxEmpty(
        icon: Icons.cloud_off_rounded,
        title: _error!,
        message: 'Kiểm tra kết nối mạng rồi thử lại.',
        action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
      );
    }
    final d = _data!;
    final rows = _filtered(_only);
    final pageRows = fxPage(rows, _vehPage, _vehiclesPerPage);
    final live = _day.live;
    final allAlerts = live ? d.alerts : _day.alerts;
    final alerts = fxPage(allAlerts, _alertPage, _alertsPerPage);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
        children: [
          _hero(t, d),
          _activityCard(t, d),
          _mapCard(t, d),
          // Alerts
          FxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.notifications_active_outlined,
                  title: live ? 'Cảnh báo cần xử lý' : 'Cảnh báo trong ngày',
                  subtitle: _day.subtitle,
                  tone: FxTokens.red,
                  trailing: !live && _day.loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : FxPill(label: '${allAlerts.length}', tone: allAlerts.isEmpty ? FxTokens.emerald : FxTokens.red, solid: allAlerts.isNotEmpty),
                ),
                FxAlertDayBar(ctl: _day),
                SizedBox(height: 10.h),
                if (!live && _day.error != null) FxBanner(text: _day.error!, tone: FxTokens.red, icon: Icons.cloud_off_rounded),
                if (!live && _day.loading && allAlerts.isEmpty)
                  Padding(padding: EdgeInsets.symmetric(vertical: 24.h), child: const Center(child: CircularProgressIndicator()))
                else if (allAlerts.isEmpty)
                  FxEmpty(
                    icon: Icons.verified_outlined,
                    title: 'Không có cảnh báo',
                    message: live ? 'Mọi xe đang hoạt động bình thường.' : 'Ngày này không có tụt dầu hay bê tông cần kiểm tra.',
                  )
                else ...[
                  for (final a in alerts) _alertTile(t, a),
                  FxPager(page: _alertPage, total: allAlerts.length, size: _alertsPerPage, onChanged: (p) => setState(() => _alertPage = p)),
                ],
              ],
            ),
          ),
          // Vehicles
          FxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.local_shipping_outlined,
                  title: 'Danh sách xe',
                  subtitle: 'Chạm vào xe để xem vị trí trên bản đồ',
                  tone: FxTokens.blue,
                ),
                FxSearchField(
                  hint: 'Tìm xe, biển số…',
                  onChanged: (v) => setState(() {
                    _q = v;
                    _vehPage = 0;
                  }),
                ),
                SizedBox(height: 10.h),
                FxSegmented<String>(
                  dense: true,
                  segments: [
                    FxSegment('all', 'Tất cả · ${_filtered('all').length}'),
                    FxSegment('alert', 'Cảnh báo · ${_filtered('alert').length}'),
                    FxSegment('can', 'Có CAN · ${_filtered('can').length}'),
                  ],
                  value: _only,
                  onChanged: (v) => setState(() {
                    _only = v;
                    _vehPage = 0;
                  }),
                ),
                SizedBox(height: 12.h),
                if (rows.isEmpty) const FxEmpty(icon: Icons.search_off_rounded, title: 'Không có xe phù hợp'),
                for (final v in pageRows) _vehicleTile(t, v),
                FxPager(page: _vehPage, total: rows.length, size: _vehiclesPerPage, onChanged: (p) => setState(() => _vehPage = p)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(FxTokens t, FleetOverview d) {
    final tt = d.totals;
    Widget mini(IconData icon, String label, int value, Color accent) => Expanded(
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14.r)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 14.sp, color: Colors.white.withValues(alpha: 0.85)),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.85))),
                  ),
                ]),
                SizedBox(height: 4.h),
                Row(children: [
                  Text('$value', style: t.num(20.sp, color: Colors.white)),
                  if (value > 0) ...[
                    SizedBox(width: 6.w),
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  ],
                ]),
              ],
            ),
          ),
        );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
        ),
        boxShadow: [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LiveDot(),
              SizedBox(width: 6.w),
              Text('Trực tiếp · cập nhật ${_updatedAt == null ? '…' : DateFormat('HH:mm:ss').format(_updatedAt!)}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.85))),
              const Spacer(),
              if (_loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${tt.vehicles}', style: t.num(40.sp, color: Colors.white)),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(bottom: 6.h),
                child: Text('xe đang giám sát', style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9))),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '${tt.withCan} xe có dữ liệu CAN${tt.noTankSize > 0 ? ' · ${tt.noTankSize} xe chưa nhập dung tích bình' : ''}',
            style: TextStyle(fontSize: 11.5.sp, color: Colors.white.withValues(alpha: 0.8)),
          ),
          SizedBox(height: 14.h),
          Row(children: [
            mini(Icons.local_gas_station_rounded, 'Tụt dầu (7 ngày)', tt.fuelAlerts, const Color(0xFFFCA5A5)),
            SizedBox(width: 8.w),
            mini(Icons.blender_rounded, 'Bê tông hôm nay', tt.concreteAlerts, const Color(0xFFFCD34D)),
          ]),
        ],
      ),
    );
  }

  Widget _activityCard(FxTokens t, FleetOverview d) {
    final counts = <String, int>{};
    for (final v in d.vehicles) {
      counts[v.activity] = (counts[v.activity] ?? 0) + 1;
    }
    const order = ['moving', 'idle', 'stopped', 'stationary', 'no_data', 'unknown'];
    final parts = [
      for (final k in order)
        if ((counts[k] ?? 0) > 0) (key: k, n: counts[k]!),
      for (final e in counts.entries)
        if (!order.contains(e.key)) (key: e.key, n: e.value),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Trạng thái đội xe', style: t.h3),
            const Spacer(),
            Text('${d.vehicles.length} xe', style: t.small),
          ]),
          SizedBox(height: 10.h),
          FxStackBar(height: 10, parts: [for (final p in parts) (value: p.n.toDouble(), color: activityOf(p.key).color)]),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 14.w,
            runSpacing: 6.h,
            children: [for (final p in parts) FxLegend(color: activityOf(p.key).color, label: activityOf(p.key).label, value: '${p.n}')],
          ),
        ],
      ),
    );
  }

  Widget _mapCard(FxTokens t, FleetOverview d) {
    final pts = d.vehicles.where((v) => v.lat != null && v.lon != null).toList();
    final rv = d.vehicles.where((v) => v.fleetVehicleId == _routeVid).firstOrNull;
    final showRoute = rv != null && (_rRoute.isNotEmpty || _rStops.isNotEmpty);
    final others = pts.where((v) => v.fleetVehicleId != _routeVid).toList();
    final checks = _rStops.where((e) => e.risk?.level == 'check').length;
    final fuelEv = _rStops.where((e) => e.category == 'fuel').length;

    Widget mapWidget() => showRoute
        ? FxTripRouteMap(
            key: ValueKey('ov_${_routeVid}_${_rRoute.length}_${_rStops.length}'),
            route: _rRoute,
            routeTs: _rTs,
            stops: _rStops,
            yards: _yards,
            onSelect: _openStop,
            vehicleName: rv.displayName,
            plate: rv.plate,
            fitPadding: const EdgeInsets.fromLTRB(40, 70, 40, 150),
            extraLayers: [
              MarkerLayer(markers: [
                for (final v in others)
                  Marker(
                    point: LatLng(v.lat!, v.lon!),
                    width: 110,
                    height: 64,
                    child: GestureDetector(onTap: () => _focus(v), child: _VehicleMarker(v: v, selected: false, dim: true)),
                  ),
              ]),
            ],
          )
        : _FleetMap(vehicles: pts, selected: _selected, controller: _map, onTap: _focus);

    return FxCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: showRoute ? 440.h : 270.h,
        child: pts.isEmpty
            ? const FxEmpty(icon: Icons.map_outlined, title: 'Chưa có vị trí xe')
            : Stack(
                children: [
                  Positioned.fill(child: mapWidget()),
                  Positioned(
                    left: 10.w,
                    top: 10.h,
                    right: 60.w,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _glass(
                        t,
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(showRoute ? Icons.route_rounded : Icons.map_rounded, size: 14.sp, color: t.text),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              showRoute ? 'Lộ trình ${rv.displayName}' : 'Vị trí xe · ${pts.length} · chạm xe để xem lộ trình',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.h3.copyWith(fontSize: 12.sp),
                            ),
                          ),
                          if (_rLoading) ...[
                            SizedBox(width: 8.w),
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10.w,
                    top: 10.h,
                    child: showRoute
                        ? FxMapButton(icon: Icons.close_rounded, tooltip: 'Về bản đồ đội xe', onTap: _closeRoute)
                        : FxMapButton(
                            icon: Icons.fullscreen_rounded,
                            tooltip: 'Toàn màn hình',
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Vị trí xe')),
                                body: _FleetMap(vehicles: pts, selected: _selected, onTap: (_) {}),
                              ),
                            )),
                          ),
                  ),
                  if (showRoute)
                    Positioned(
                      left: 10.w,
                      right: 10.w,
                      bottom: 10.h,
                      child: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: t.card.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 8)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _rTrip != null
                                  ? 'Chuyến #${_rTrip!.orderNumber ?? '—'} · ${_rTrip!.purpose == 'no_load' ? 'Không lấy hàng' : 'Giao hàng'} · ${fmtTime(_rTrip!.startedAt)} → ${_rTrip!.endedAt != null ? fmtTime(_rTrip!.endedAt) : 'đang chạy'}'
                                  : 'Chuyến #${rv.trip?.orderNumber ?? '—'} · từ ${fmtTime(rv.trip?.startedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.h3.copyWith(fontSize: 12.5.sp, fontFeatures: FxTokens.tabular),
                            ),
                            SizedBox(height: 6.h),
                            Row(children: [
                              FxPill(label: checks > 0 ? '$checks cần kiểm tra' : 'Không có điểm cần kiểm tra', tone: checks > 0 ? FxTokens.red : FxTokens.emerald),
                              if (fuelEv > 0) ...[SizedBox(width: 4.w), FxPill(label: '$fuelEv sự kiện dầu', tone: FxTokens.amber)],
                              const Spacer(),
                              if (rv.concreteEnabled && widget.perms.concrete && widget.onOpenConcrete != null)
                                InkWell(
                                  onTap: () => widget.onOpenConcrete!(rv.fleetVehicleId),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                                    child: Text('Chi tiết ›', style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: t.ink(FxTokens.blue))),
                                  ),
                                ),
                            ]),
                            SizedBox(height: 6.h),
                            const FxRouteLegend(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _glass(FxTokens t, Widget child) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: t.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 6)],
        ),
        child: child,
      );

  Widget _alertTile(FxTokens t, FleetAlert a) {
    final fuel = a.category == 'fuel';
    final tone = a.riskLevel != null ? riskOf(a.riskLevel!) : severityOf(a.severity);
    final head = a.riskLevel != null ? (a.riskReason ?? a.title) : a.title;
    final meta = <String>[fmtTime(a.startedAt, withDate: true)];
    if (fuel && a.deltaPct != null) meta.add('tụt ${fmtNum(a.deltaPct, 1)}%${a.dropL != null ? ' ≈ ${fmtNum(a.dropL, 0)} L' : ''}');
    if (!fuel) {
      meta.add(fmtDur(a.durationS));
      if (a.discharge == true) meta.add('vòng tua cao');
    }
    final read = FleetReads.instance.isRead(a.id);
    final seen = FleetReads.instance.readers(a.id);
    if (seen > 0) meta.add('$seen người đã xem');
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () => showFxEventSheet(
            context,
            eventId: a.id,
            category: a.category,
            cameraAllowed: widget.perms.concreteReview,
            onChanged: () {
              _load(quiet: true);
              _day.load();
            },
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border(left: BorderSide(color: tone.color, width: 4)),
            ),
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 8.w, 10.h),
            child: Row(
              children: [
                FxIconBadge(icon: fuel ? Icons.local_gas_station_rounded : Icons.blender_rounded, tone: fuel ? FxTokens.red : FxTokens.amber, size: 34),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (!read) ...[
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: FxTokens.blue, shape: BoxShape.circle)),
                          SizedBox(width: 6.w),
                        ],
                        Flexible(child: Text(a.vehicleCode, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 6.w),
                        FxPill(label: tone.label, tone: tone.color),
                        if (a.reviewed) ...[SizedBox(width: 4.w), const FxReviewedPill()],
                      ]),
                      SizedBox(height: 3.h),
                      Text(head,
                          style: t.small.copyWith(color: t.text, fontWeight: read ? FontWeight.w400 : FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      SizedBox(height: 2.h),
                      Text(meta.join(' · '), style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vehicleTile(FxTokens t, FleetOverviewVehicle v) {
    final act = activityOf(v.activity);
    final sel = v.fleetVehicleId == _selected;
    final lvl = v.fuelLevelPct;
    final low = lvl != null && lvl < 20;
    final fuelColor = lvl == null ? t.textFaint : (low ? FxTokens.red : FxTokens.emerald);
    final canFuel = widget.perms.fuel && widget.onOpenFuel != null;
    final canConcrete = widget.perms.concrete && v.concreteEnabled && widget.onOpenConcrete != null;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: sel ? t.soft(FxTokens.blue) : t.cardAlt,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: () => _focus(v),
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: sel ? FxTokens.blue.withValues(alpha: 0.5) : t.border),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FxGauge(
                      value: lvl,
                      size: 52.w,
                      stroke: 5,
                      color: fuelColor,
                      center: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(lvl == null ? '—' : '${lvl.round()}', style: t.num(13.sp, color: lvl == null ? t.textFaint : t.text)),
                        Text(lvl == null ? (v.hasCan ? 'chờ' : 'no CAN') : '%', style: TextStyle(fontSize: 8.sp, color: t.textMuted)),
                      ]),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(v.displayName, style: t.h3.copyWith(fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            SizedBox(width: 6.w),
                            FxPill(label: act.label, tone: act.color, dot: true),
                          ]),
                          SizedBox(height: 2.h),
                          Text('${v.plate}${v.type != null ? ' · ${v.type}' : ''}', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                          if (v.address?.isNotEmpty == true) ...[
                            SizedBox(height: 3.h),
                            Row(children: [
                              Icon(Icons.place_outlined, size: 12.sp, color: t.textFaint),
                              SizedBox(width: 3.w),
                              Expanded(child: Text(v.address!, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ]),
                          ],
                          SizedBox(height: 3.h),
                          Text(
                            lvl == null
                                ? (v.hasCan ? 'Chưa có mức dầu mới' : 'Chưa lắp CAN')
                                : (v.fuelLevelL != null
                                    ? '≈ ${fmtNum(v.fuelLevelL, 0)} / ${fmtNum(v.tankCapacityL, 0)} L'
                                    : 'Chưa nhập dung tích bình'),
                            style: t.tiny.copyWith(
                              color: lvl != null && v.fuelLevelL == null ? t.ink(FxTokens.amber) : t.textMuted,
                              fontFeatures: FxTokens.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(Icons.route_rounded, size: 13.sp, color: v.trip != null ? t.ink(FxTokens.blue) : t.textFaint),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        v.trip != null
                            ? 'Chuyến #${v.trip!.orderNumber ?? '—'} · ${v.trip!.purpose == 'no_load' ? 'Không lấy hàng' : 'Giao hàng'} · từ ${fmtTime(v.trip!.startedAt)}'
                            : 'Không trong chuyến',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.tiny.copyWith(
                          color: v.trip != null ? t.ink(FxTokens.blue) : t.textMuted,
                          fontWeight: v.trip != null ? FontWeight.w700 : FontWeight.w400,
                          fontFeatures: FxTokens.tabular,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    _count(t, Icons.local_gas_station_rounded, v.fuelAlerts, true),
                    SizedBox(width: 6.w),
                    _count(t, Icons.blender_rounded, v.concreteAlerts, v.concreteEnabled),
                  ],
                ),
                if (canFuel || canConcrete) ...[
                  SizedBox(height: 8.h),
                  Divider(height: 1, color: t.border),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      if (canFuel)
                        Expanded(child: _action(t, Icons.local_gas_station_outlined, 'Nhiên liệu', () => widget.onOpenFuel!(v.fleetVehicleId))),
                      if (canFuel && canConcrete) SizedBox(width: 8.w),
                      if (canConcrete)
                        Expanded(child: _action(t, Icons.blender_outlined, 'Bê tông thừa', () => widget.onOpenConcrete!(v.fleetVehicleId))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(FxTokens t, IconData icon, int n, bool applies) {
    final tone = !applies ? FxTokens.slate : (n > 0 ? FxTokens.red : FxTokens.emerald);
    return Tooltip(
      message: applies ? '$n cảnh báo' : 'Không áp dụng',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
        decoration: BoxDecoration(color: t.soft(tone), borderRadius: BorderRadius.circular(8.r)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12.sp, color: t.ink(tone)),
          SizedBox(width: 3.w),
          Text(applies ? '$n' : '–', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: t.ink(tone), fontFeatures: FxTokens.tabular)),
        ]),
      ),
    );
  }

  Widget _action(FxTokens t, IconData icon, String label, VoidCallback onTap) => TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16.sp),
        label: Text(label, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700)),
        style: TextButton.styleFrom(
          foregroundColor: t.ink(FxTokens.blue),
          backgroundColor: t.soft(FxTokens.blue),
          padding: EdgeInsets.symmetric(vertical: 8.h),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
}

class _FleetMap extends StatelessWidget {
  final List<FleetOverviewVehicle> vehicles;
  final String? selected;
  final MapController? controller;
  final ValueChanged<FleetOverviewVehicle> onTap;

  const _FleetMap({required this.vehicles, required this.selected, this.controller, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints(vehicles.map((v) => LatLng(v.lat!, v.lon!)).toList());
    final sorted = [...vehicles]..sort((a, b) => _VehicleMarker.zOf(a, selected).compareTo(_VehicleMarker.zOf(b, selected)));
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCameraFit: vehicles.length > 1 ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50), maxZoom: 15) : null,
        initialCenter: LatLng(vehicles.first.lat!, vehicles.first.lon!),
        initialZoom: 13,
      ),
      children: [
        TileLayer(urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', userAgentPackageName: 'com.nguyenanh.nagapp'),
        MarkerLayer(
          markers: [
            for (final v in sorted)
              Marker(
                point: LatLng(v.lat!, v.lon!),
                width: 110,
                height: 64,
                child: GestureDetector(onTap: () => onTap(v), child: _VehicleMarker(v: v, selected: v.fleetVehicleId == selected)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Same rule as the web overview map: alert > offline (> 10 min without data) > moving > parked.
class _VehicleMarker extends StatelessWidget {
  final FleetOverviewVehicle v;
  final bool selected;
  final bool dim;
  const _VehicleMarker({required this.v, required this.selected, this.dim = false});

  static String statusOf(FleetOverviewVehicle v) {
    if (v.fuelAlerts + v.concreteAlerts > 0) return 'alert';
    if (v.dataAgeS == null || v.dataAgeS! > 600) return 'offline';
    return v.activity == 'moving' || (v.speedKmh ?? 0) > 3 ? 'run' : 'park';
  }

  static int zOf(FleetOverviewVehicle v, String? selected) =>
      v.fleetVehicleId == selected ? 3 : (statusOf(v) == 'alert' ? 2 : 1);

  @override
  Widget build(BuildContext context) {
    final st = statusOf(v);
    final border = st == 'alert' ? FxTokens.red : (selected ? FxTokens.blue : null);
    return FxTruckMarker(
      heading: v.heading,
      name: v.displayName,
      plate: v.plate,
      border: border,
      size: selected ? 44 : 36,
      dim: dim || st == 'offline',
      statusColor: switch (st) {
        'alert' => FxTokens.red,
        'run' => FxTokens.green,
        'park' => FxTokens.blue,
        _ => FxTokens.slate,
      },
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(
            width: 6 + 8 * _c.value,
            height: 6 + 8 * _c.value,
            decoration: BoxDecoration(color: const Color(0xFF4ADE80).withValues(alpha: 1 - _c.value), shape: BoxShape.circle),
          ),
          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
        ]),
      ),
    );
  }
}
