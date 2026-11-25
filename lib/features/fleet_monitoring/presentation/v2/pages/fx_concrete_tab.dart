import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_event_sheet.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_trip_route_map.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_vehicle_picker.dart';

/// "Bê tông thừa" (v2). Same data rules as v1 (trips + rich stop events per day, route of one trip), new layout.
class FxConcreteTab extends StatefulWidget {
  final FleetPermissions perms;
  final ValueNotifier<String?> request;

  const FxConcreteTab({super.key, required this.perms, required this.request});

  @override
  State<FxConcreteTab> createState() => _FxConcreteTabState();
}

class _FxConcreteTabState extends State<FxConcreteTab> with AutomaticKeepAliveClientMixin {
  static const _storeKey = 'fleet-concrete-vehicle';

  final _api = FleetMonitoringService();
  List<FleetVehicle> _vehicles = [];
  bool _vehiclesLoaded = false;
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
  final _tripScroll = ScrollController();

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
    _tripScroll.dispose();
    super.dispose();
  }

  // ── Data (same rules as v1) ───────────────────────────────────────────────

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
        _vehiclesLoaded = true;
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
    setState(() => _loading = true);
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

  List<FleetEvent> get _shown {
    int rank(FleetEvent e) => e.risk == null || e.risk!.level == 'check'
        ? 0
        : e.risk!.level == 'delivery'
            ? 1
            : 2;
    return _tripEvents.where((e) => _showNormal || rank(e) < 2).toList()
      ..sort((a, b) {
        final r = rank(a) - rank(b);
        return r != 0 ? r : a.startedAt.compareTo(b.startedAt);
      });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year - 2), lastDate: now, initialDate: _day);
    if (d == null) return;
    setState(() => _day = d);
    _load();
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = FxTokens.of(context);
    final now = DateTime.now();
    final dayKey = _sameDay(_day, now)
        ? 'today'
        : _sameDay(_day, now.subtract(const Duration(days: 1)))
            ? 'yday'
            : 'other';

    if (_vehiclesLoaded && _vehicles.isEmpty) {
      return ListView(padding: EdgeInsets.all(14.w), children: const [
        FxEmpty(icon: Icons.blender_outlined, title: 'Chưa có xe bồn nào được giám sát'),
      ]);
    }

    final deliveries = _trips.where((x) => x.purpose == 'delivery').length;
    final flagged = _events.where((e) => e.risk?.level == 'check').length;
    final discharges = _events.where((e) => e.evidence['discharge_signature'] == true).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
        children: [
          FxVehicleHeader(vehicles: _vehicles, selectedId: _vid, onChanged: _setVehicle, emptyText: 'Không có xe bồn'),
          FxSegmented<String>(
            segments: [
              const FxSegment('today', 'Hôm nay'),
              const FxSegment('yday', 'Hôm qua'),
              FxSegment('other', dayKey == 'other' ? DateFormat('dd/MM/yyyy').format(_day) : 'Chọn ngày', icon: Icons.event_rounded),
            ],
            value: dayKey,
            onChanged: (v) {
              if (v == 'other') {
                _pickDay();
                return;
              }
              setState(() => _day = v == 'today' ? DateTime.now() : DateTime.now().subtract(const Duration(days: 1)));
              _load();
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 10.h),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 13.sp, color: t.textFaint),
              SizedBox(width: 4.w),
              Expanded(child: Text('Chỉ xe bồn · theo chuyến giao hàng · không kiểm tra trong bãi/trạm', style: t.tiny)),
              if (_loading) SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: t.textMuted)),
            ]),
          ),
          if (_error != null) FxBanner(text: _error!, tone: FxTokens.red, icon: Icons.cloud_off_rounded),
          FxGrid(columns: 2, children: [
            FxKpi(icon: Icons.local_shipping_rounded, label: 'Chuyến giao hàng', value: '$deliveries', tone: FxTokens.blue),
            FxKpi(icon: Icons.u_turn_left_rounded, label: 'Không lấy hàng', value: '${_trips.length - deliveries}', tone: FxTokens.slate),
            FxKpi(icon: Icons.report_problem_rounded, label: 'Dừng cần kiểm tra', value: '$flagged', tone: FxTokens.red),
            FxKpi(icon: Icons.rotate_right_rounded, label: 'Xả theo vòng tua', value: '$discharges', tone: FxTokens.amber),
          ]),
          _tripStrip(t),
          _mapCard(t),
          _stopsCard(t),
        ],
      ),
    );
  }

  Widget _tripStrip(FxTokens t) {
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 0, 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(right: 14.w),
            child: FxSectionHeader(
              icon: Icons.route_rounded,
              title: 'Chuyến trong ngày',
              subtitle: _trips.isEmpty ? null : '${_trips.length} chuyến · chạm để xem lộ trình',
              tone: FxTokens.blue,
            ),
          ),
          if (_trips.isEmpty && !_loading)
            const FxEmpty(icon: Icons.event_busy_rounded, title: 'Không có chuyến trong ngày')
          else if (_trips.isEmpty)
            Padding(padding: EdgeInsets.only(right: 14.w), child: FxSkeleton(height: 92.h))
          else
            SizedBox(
              height: 104.h,
              child: ListView.separated(
                controller: _tripScroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(right: 14.w),
                itemCount: _trips.length,
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (_, i) => _tripCard(t, _trips[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tripCard(FxTokens t, FleetTrip tr) {
    final sel = tr.tripId == _tripId;
    final check = tr.risk?.check ?? 0;
    final delivery = tr.purpose == 'delivery';
    final fg = sel ? Colors.white : t.text;
    final muted = sel ? Colors.white.withValues(alpha: 0.8) : t.textMuted;
    return GestureDetector(
      onTap: () => _selectTrip(tr.tripId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150.w,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          gradient: sel ? const LinearGradient(colors: [FxTokens.blue, FxTokens.indigo], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: sel ? null : t.cardAlt,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: sel ? Colors.transparent : (check > 0 ? FxTokens.red.withValues(alpha: 0.4) : t.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('#${tr.orderNumber ?? '—'}', style: t.num(16.sp, color: fg)),
              const Spacer(),
              if (!tr.concreteChecked)
                Icon(Icons.remove_circle_outline_rounded, size: 16.sp, color: muted)
              else if (check > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(color: sel ? Colors.white : FxTokens.red, borderRadius: BorderRadius.circular(8)),
                  child: Text('$check', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: sel ? FxTokens.red : Colors.white)),
                )
              else
                Icon(Icons.check_circle_rounded, size: 16.sp, color: sel ? Colors.white : FxTokens.emerald),
            ]),
            SizedBox(height: 4.h),
            Text('${fmtTime(tr.startedAt)} → ${tr.endedAt != null ? fmtTime(tr.endedAt) : 'đang chạy'}',
                style: TextStyle(fontSize: 11.5.sp, color: fg, fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular)),
            const Spacer(),
            Row(children: [
              Icon(delivery ? Icons.local_shipping_outlined : Icons.u_turn_left_rounded, size: 13.sp, color: muted),
              SizedBox(width: 4.w),
              Expanded(child: Text(delivery ? 'Giao hàng' : 'Không lấy hàng', style: TextStyle(fontSize: 10.5.sp, color: muted), maxLines: 1)),
              Text(fmtNum(tr.fuel.fuelUsedL, 1, 'L'), style: TextStyle(fontSize: 10.5.sp, color: muted, fontFeatures: FxTokens.tabular)),
            ]),
            if (tr.risk?.uncertain == true)
              Text('chưa rõ điểm giao', style: TextStyle(fontSize: 10.sp, color: sel ? Colors.white : t.ink(FxTokens.red), fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _mapCard(FxTokens t) {
    final trip = _trip;
    final idx = trip == null ? -1 : _trips.indexOf(trip);
    final stops = _shown.where((e) => e.lat != null && e.lon != null).toList();
    final all = [..._route, ...stops.map((e) => LatLng(e.lat!, e.lon!))];
    final vehicle = _vehicles.where((v) => v.fleetVehicleId == _vid).firstOrNull;

    Widget roundBtn(IconData icon, String tip, VoidCallback? onTap) => FxMapButton(icon: icon, tooltip: tip, onTap: onTap);

    final map = all.isEmpty
        ? Container(
            color: t.cardAlt,
            child: FxEmpty(icon: Icons.map_outlined, title: trip == null ? 'Chọn một chuyến để xem' : 'Chưa có dữ liệu vị trí'),
          )
        : FxTripRouteMap(
            key: ValueKey('${_vid}_${_tripId}_${_route.length}_${stops.length}'),
            route: _route,
            routeTs: _routeTs,
            stops: _shown,
            yards: _yards,
            onSelect: _openEvent,
            vehicleName: vehicle?.displayName,
            plate: vehicle?.plate,
            fitPadding: const EdgeInsets.fromLTRB(40, 70, 40, 110),
          );

    return FxCard(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 340.h,
        child: Stack(
          children: [
            Positioned.fill(child: map),
            Positioned(
              left: 10.w,
              right: 10.w,
              top: 10.h,
              child: Row(children: [
                roundBtn(Icons.chevron_left_rounded, 'Chuyến trước', idx < 0 || idx >= _trips.length - 1 ? null : () => _selectTrip(_trips[idx + 1].tripId)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: t.card.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 6)],
                    ),
                    child: Text(
                      trip != null
                          ? 'Chuyến #${trip.orderNumber ?? ''} · ${fmtTime(trip.startedAt)} → ${trip.endedAt != null ? fmtTime(trip.endedAt) : 'đang chạy'}'
                          : 'Lộ trình chuyến',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.h3.copyWith(fontSize: 12.5.sp, fontFeatures: FxTokens.tabular),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                roundBtn(Icons.chevron_right_rounded, 'Chuyến sau', idx <= 0 ? null : () => _selectTrip(_trips[idx - 1].tripId)),
              ]),
            ),
            Positioned(
              left: 10.w,
              bottom: 10.h,
              right: 10.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: t.card.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 6)],
                ),
                child: const FxRouteLegend(),
              ),
            ),
            if (_routeLoading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
          ],
        ),
      ),
    );
  }

  Widget _stopDot(FleetEvent s, int no, double size) {
    final delivery = s.risk?.level == 'delivery';
    final c = s.risk != null ? riskOf(s.risk!.level).color : severityOf(s.severity).color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x440F172A), blurRadius: 4)],
      ),
      child: delivery
          ? Icon(Icons.flag_rounded, size: size * 0.5, color: Colors.white)
          : Text('$no', style: TextStyle(color: Colors.white, fontSize: size * 0.38, fontWeight: FontWeight.w800)),
    );
  }

  Widget _stopsCard(FxTokens t) {
    final shown = _shown;
    final normalCount = _tripEvents.where((e) => e.risk?.level == 'normal').length;
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.pin_drop_outlined,
            title: 'Điểm dừng của chuyến',
            subtitle: 'Cần kiểm tra trước, sau đó là điểm giao',
            tone: FxTokens.red,
            trailing: shown.isEmpty ? null : FxPill(label: '${shown.length}', tone: FxTokens.slate),
          ),
          if (shown.isEmpty)
            FxEmpty(
              icon: Icons.pin_drop_outlined,
              title: _trip != null ? 'Chuyến này không có lần dừng nào được ghi nhận' : 'Chọn một chuyến để xem',
            ),
          for (var i = 0; i < shown.length; i++) _stopRow(t, shown[i], i + 1, i == shown.length - 1 && normalCount == 0),
          if (normalCount > 0)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showNormal = !_showNormal),
                icon: Icon(_showNormal ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16.sp),
                label: Text('${_showNormal ? 'Ẩn' : 'Xem'} $normalCount lần dừng bình thường'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textMuted,
                  side: BorderSide(color: t.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stopRow(FxTokens t, FleetEvent e, int no, bool last) {
    final tone = e.risk != null ? riskOf(e.risk!.level) : severityOf(e.severity);
    final reason = e.risk?.reason ?? e.risk?.note;
    return InkWell(
      onTap: () => _openEvent(e.id),
      borderRadius: BorderRadius.circular(12.r),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(children: [
              _stopDot(e, no, 28),
              if (!last) Expanded(child: Container(width: 2, margin: EdgeInsets.symmetric(vertical: 2.h), color: t.border)),
            ]),
            SizedBox(width: 10.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(fmtTime(e.startedAt), style: t.h3.copyWith(fontFeatures: FxTokens.tabular)),
                      SizedBox(width: 6.w),
                      Text('· ${fmtDur(e.durationS)}', style: t.tiny),
                      const Spacer(),
                      FxPill(label: tone.label, tone: tone.color),
                    ]),
                    if (e.risk == null) ...[SizedBox(height: 2.h), Text(e.title, style: t.small.copyWith(color: t.text))],
                    if (reason != null && reason.isNotEmpty) ...[SizedBox(height: 3.h), Text(reason, style: t.small.copyWith(color: t.text))],
                    if (e.risk?.position != null) ...[SizedBox(height: 2.h), Text(e.risk!.position!, style: t.tiny)],
                    if (e.address?.isNotEmpty == true) ...[
                      SizedBox(height: 3.h),
                      Row(children: [
                        Icon(Icons.place_outlined, size: 12.sp, color: t.textFaint),
                        SizedBox(width: 3.w),
                        Expanded(child: Text(e.address!, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                    if (e.thumbUrl != null) ...[
                      SizedBox(height: 6.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10.r),
                        child: Image.network(
                          FleetMonitoringService.mediaUrl(e.thumbUrl!),
                          height: 90.h,
                          width: 150.w,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEvent(String id) => showFxEventSheet(
        context,
        eventId: id,
        category: 'concrete',
        cameraAllowed: widget.perms.concreteReview,
        onChanged: _load,
      );
}
