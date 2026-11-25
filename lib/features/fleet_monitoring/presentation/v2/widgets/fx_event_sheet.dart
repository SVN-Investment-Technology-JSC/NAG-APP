import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_video_player.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_trip_route_map.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// Detail of a fuel / concrete event (same data and actions as v1, new layout).
Future<void> showFxEventSheet(
  BuildContext context, {
  required String eventId,
  required String category,
  bool cameraAllowed = false,
  VoidCallback? onChanged,
}) {
  final t = FxTokens.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: t.bg,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
    clipBehavior: Clip.antiAlias,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, scroll) =>
          _Body(eventId: eventId, category: category, cameraAllowed: cameraAllowed, onChanged: onChanged, scroll: scroll),
    ),
  );
}

class _Body extends StatefulWidget {
  final String eventId;
  final String category;
  final bool cameraAllowed;
  final VoidCallback? onChanged;
  final ScrollController scroll;

  const _Body({required this.eventId, required this.category, required this.cameraAllowed, required this.onChanged, required this.scroll});

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _api = FleetMonitoringService();
  FleetEvent? _ev;
  bool _loading = true;
  String? _error;
  late String _curId = widget.eventId; // another stop of the same trip can be opened from the map

  // Whole trip of a concrete stop (as the web's EventTripMap): loaded once per trip.
  String? _tripKey;
  FleetTrip? _trip;
  List<FleetEvent> _tripStops = [];
  List<LatLng> _route = [];
  List<int> _routeTs = [];
  List<FleetGeofence> _yards = [];
  bool _tripLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.category == 'concrete') {
      _api.geofences().then((g) {
        if (mounted) setState(() => _yards = g);
      }).catchError((_) {});
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = widget.category == 'fuel' ? await _api.fuelEvent(_curId) : await _api.concreteEvent(_curId);
      if (!mounted) return;
      setState(() {
        _ev = d;
        _error = null;
        _loading = false;
      });
      if (widget.category == 'concrete' && d.tripId != null) _loadTrip(d);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được sự kiện';
        _loading = false;
      });
    }
  }

  Future<void> _loadTrip(FleetEvent ev) async {
    final key = '${ev.vehicleId}|${ev.tripId}';
    if (key == _tripKey) return;
    _tripKey = key;
    final at = parseTime(ev.startedAt);
    if (at == null) return;
    setState(() => _tripLoading = true);
    try {
      final t = toUnix(at);
      final trips = await _api.trips(ev.vehicleId, t - 12 * 3600, t + 12 * 3600);
      final tr = trips.where((x) => x.tripId == ev.tripId).firstOrNull;
      if (!mounted || key != _tripKey) return;
      if (tr == null) {
        setState(() => _trip = null);
        return;
      }
      final from = toUnix(parseTime(tr.startedAt) ?? at) - 120;
      final to = toUnix(parseTime(tr.endedAt) ?? DateTime.now()) + 120;
      final res = await Future.wait([
        _api.concreteEvents(vehicleId: ev.vehicleId, from: from, to: to, limit: 200),
        _api.routeSeries(ev.vehicleId, from, to),
      ]);
      if (!mounted || key != _tripKey) return;
      final stops = (res[0] as List<FleetEvent>).where((e) => e.tripId == ev.tripId).toList()
        ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
      final s = res[1] as FleetSeries;
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
        _trip = tr;
        _tripStops = stops;
        _route = pts;
        _routeTs = tss;
      });
    } catch (_) {
      if (mounted && key == _tripKey) setState(() => _trip = null);
    } finally {
      if (mounted && key == _tripKey) setState(() => _tripLoading = false);
    }
  }

  void _openStop(String id) {
    if (id == _curId) return;
    setState(() => _curId = id);
    _load();
  }

  Widget _tripMapCard(FxTokens t, FleetEvent ev) {
    final tr = _trip;
    final checks = _tripStops.where((s) => s.risk?.level == 'check').length;
    return FxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 8.h),
            child: Row(children: [
              const FxIconBadge(icon: Icons.route_rounded, tone: FxTokens.blue, size: 30),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    tr != null
                        ? 'Lộ trình chuyến #${tr.orderNumber ?? ''} (${fmtTime(tr.startedAt)} → ${tr.endedAt != null ? fmtTime(tr.endedAt) : 'đang chạy'})'
                        : 'Lộ trình chuyến',
                    style: t.h3,
                  ),
                  if (tr != null) Text('${_tripStops.length} lần dừng · $checks cần kiểm tra', style: t.tiny),
                ]),
              ),
              if (_tripLoading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
          SizedBox(
            height: 300.h,
            child: tr == null
                ? (_tripLoading
                    ? const Center(child: CircularProgressIndicator.adaptive())
                    : SizedBox(height: 190.h, child: _MiniMap(lat: ev.lat!, lon: ev.lon!, color: riskOf(ev.risk?.level ?? 'normal').color)))
                : FxTripRouteMap(
                    key: ValueKey('${_tripKey}_${_route.length}_${_tripStops.length}'),
                    route: _route,
                    routeTs: _routeTs,
                    stops: _tripStops,
                    yards: _yards,
                    selectedId: ev.id,
                    onSelect: _openStop,
                    vehicleName: ev.vehicleCode,
                    plate: ev.vehiclePlate,
                    fitPadding: const EdgeInsets.all(40),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 0),
            child: const FxRouteLegend(),
          ),
          if (tr != null)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 0),
              child: Text('Lần dừng đang xem được phóng to — chạm ghim khác để xem lần dừng đó.', style: t.tiny, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Future<void> _askCamera(String kind) async {
    final ev = _ev;
    if (ev == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.cameraJob(ev.id, kind);
      messenger.showSnackBar(SnackBar(
        content: Text(kind == 'clip'
            ? 'Đã yêu cầu video — video ghi lại cần thời gian bằng độ dài đoạn quay'
            : 'Đã yêu cầu ảnh từ camera'),
      ));
      widget.onChanged?.call();
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _load();
      });
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không gửi được yêu cầu camera')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final ev = _ev;
    if (_loading && ev == null) {
      return ListView(controller: widget.scroll, padding: EdgeInsets.all(16.w), children: [
        _handle(t),
        FxSkeleton(height: 110.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 120.h),
        SizedBox(height: 12.h),
        FxSkeleton(height: 180.h),
      ]);
    }
    if (ev == null) {
      return ListView(controller: widget.scroll, children: [
        _handle(t),
        FxEmpty(
          icon: Icons.cloud_off_rounded,
          title: _error ?? 'Không có dữ liệu',
          action: FilledButton.tonal(onPressed: _load, child: const Text('Thử lại')),
        ),
      ]);
    }

    final evd = ev.evidence;
    final risk = ev.risk;
    final tone = risk != null ? riskOf(risk.level) : severityOf(ev.severity);
    final title = risk != null
        ? (risk.level == 'delivery'
            ? 'Điểm giao của chuyến'
            : risk.level == 'check'
                ? 'Lần dừng cần kiểm tra'
                : 'Lần dừng bình thường')
        : ev.title;
    final images = ev.media.where((m) => m.contentType.startsWith('image/')).toList();
    final videos = ev.media.where((m) => m.contentType.startsWith('video/')).toList();
    final pending = ev.cameraJobStatuses.any((s) => s == 'pending' || s == 'running');
    num? n(String k) => evd[k] is num ? evd[k] as num : null;

    final facts = <(IconData, String, String)>[
      (Icons.schedule_rounded, 'Bắt đầu', fmtTime(ev.startedAt, withDate: true)),
      (Icons.flag_outlined, 'Kết thúc', fmtTime(ev.endedAt, withDate: true)),
      (Icons.timer_outlined, 'Thời lượng', fmtDur(ev.durationS)),
      if (widget.category == 'fuel')
        (
          Icons.trending_down_rounded,
          'Mức tụt',
          n('delta_pct') != null
              ? '${fmtNum(n('delta_pct'), 1)}%${n('drop_l') != null ? ' ≈ ${fmtNum(n('drop_l'), 0)} L' : ''}'
              : '—'
        )
      else
        (Icons.speed_rounded, 'Vòng tua tối đa', n('rpm_max') != null ? '${fmtNum(n('rpm_max'), 0)} rpm' : 'Không có RPM'),
      if (widget.category == 'concrete')
        (
          Icons.power_settings_new_rounded,
          'Động cơ',
          ev.engineOn == true
              ? 'Nổ máy'
              : ev.engineOn == false
                  ? 'Tắt máy'
                  : 'Chưa rõ'
        ),
      if (widget.category == 'fuel' && n('delta_pct') != null && n('drop_l') == null)
        (Icons.local_gas_station_outlined, 'Dung tích bình', 'Chưa nhập'),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: widget.scroll,
        padding: EdgeInsets.zero,
        children: [
          // Header band
          Container(
            padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 18.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tone.color.withValues(alpha: t.dark ? 0.35 : 0.16), t.bg],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(t),
                Row(
                  children: [
                    FxIconBadge(
                      icon: widget.category == 'fuel' ? Icons.local_gas_station_rounded : Icons.blender_rounded,
                      tone: tone.color,
                      size: 40,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.h1.copyWith(fontSize: 18.sp)),
                          SizedBox(height: 3.h),
                          Text('${ev.vehicleCode} · ${ev.vehiclePlate}', style: t.small),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    FxPill(label: tone.label, tone: tone.color, solid: true),
                    if (risk?.position != null) FxPill(label: risk!.position!, tone: FxTokens.slate),
                    if (ev.status == 'reviewed') FxPill(label: 'Đã duyệt: ${reviewLabel(ev.reviewLabel)}', tone: FxTokens.blue, icon: Icons.verified_rounded),
                    if (ev.code.isNotEmpty) FxPill(label: ev.code, tone: FxTokens.slate),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxGrid(columns: 2, children: [for (final f in facts) FxInfoTile(icon: f.$1, label: f.$2, value: f.$3)]),
                // Assessment
                FxCard(
                  borderColor: tone.color.withValues(alpha: 0.45),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FxSectionHeader(
                        icon: Icons.fact_check_outlined,
                        title: risk != null ? 'Đánh giá của hệ thống' : 'Vì sao hệ thống đánh dấu',
                        tone: tone.color,
                      ),
                      Text(risk != null ? (risk.reason ?? risk.note ?? '—') : ev.reason, style: t.body),
                      if (evd['discharge_signature'] != null) ...[
                        SizedBox(height: 10.h),
                        Builder(builder: (_) {
                          final yes = evd['discharge_signature'] == true;
                          return FxBanner(
                            tone: yes ? FxTokens.red : FxTokens.emerald,
                            icon: yes ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            title: yes ? 'Có dấu hiệu xả bê tông' : 'Không có dấu hiệu xả',
                            text: yes
                                ? 'Đứng yên với vòng tua ≥ ${fmtNum(n('discharge_rpm'), 0)} rpm trong ${fmtDur(n('rpm_high_s'))} — bồn quay nhanh để xả.'
                                : 'Vòng tua không vượt ${fmtNum(n('discharge_rpm'), 0)} rpm khi đứng yên.',
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                // Location: whole trip for a concrete stop (as on the web), the point otherwise
                if (widget.category == 'concrete' && ev.tripId != null && ev.lat != null && ev.lon != null) _tripMapCard(t, ev),
                if (ev.lat != null && ev.lon != null)
                  FxCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!(widget.category == 'concrete' && ev.tripId != null))
                          SizedBox(height: 190.h, child: _MiniMap(lat: ev.lat!, lon: ev.lon!, color: tone.color)),
                        Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, size: 18.sp, color: tone.color),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  ev.address?.isNotEmpty == true ? ev.address! : '${ev.lat!.toStringAsFixed(5)}, ${ev.lon!.toStringAsFixed(5)}',
                                  style: t.small.copyWith(color: t.text),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Mở Google Maps',
                                icon: Icon(Icons.directions_rounded, color: FxTokens.blue, size: 22.sp),
                                onPressed: () => launchUrl(
                                  Uri.parse('https://www.google.com/maps/search/?api=1&query=${ev.lat},${ev.lon}'),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Camera
                FxCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FxSectionHeader(
                        icon: Icons.photo_camera_outlined,
                        title: 'Ảnh & video camera',
                        subtitle: ev.cameraCount > 0 ? '${images.length} ảnh · ${videos.length} video' : 'Xe chưa gắn camera',
                        tone: FxTokens.violet,
                      ),
                      if (widget.cameraAllowed && widget.category == 'concrete' && ev.cameraCount > 0) ...[
                        Row(
                          children: [
                            Expanded(child: _camBtn(t, Icons.photo_camera_rounded, 'Chụp ảnh', () => _askCamera('snapshot'))),
                            SizedBox(width: 8.w),
                            Expanded(child: _camBtn(t, Icons.image_search_rounded, 'Ảnh lúc dừng', () => _askCamera('frame'))),
                            SizedBox(width: 8.w),
                            Expanded(child: _camBtn(t, Icons.videocam_rounded, 'Lấy video', () => _askCamera('clip'))),
                          ],
                        ),
                        SizedBox(height: 12.h),
                      ],
                      if (pending)
                        Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Row(children: [
                            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.ink(FxTokens.amber))),
                            SizedBox(width: 8.w),
                            Expanded(child: Text('Đang chờ camera gửi về… kéo xuống để tải lại', style: t.small.copyWith(color: t.ink(FxTokens.amber)))),
                          ]),
                        ),
                      if (images.isEmpty && videos.isEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 18.h),
                          decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r)),
                          child: Column(children: [
                            Icon(Icons.hide_image_outlined, color: t.textFaint, size: 26.sp),
                            SizedBox(height: 6.h),
                            Text(ev.cameraCount > 0 ? 'Chưa có ảnh/video cho sự kiện này' : 'Xe chưa gắn camera', style: t.small),
                          ]),
                        ),
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 128.h,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            separatorBuilder: (_, __) => SizedBox(width: 8.w),
                            itemBuilder: (_, i) {
                              final m = images[i];
                              final url = FleetMonitoringService.mediaUrl(m.url);
                              return GestureDetector(
                                onTap: () => _openGallery(context, images.map((x) => FleetMonitoringService.mediaUrl(x.url)).toList(), i),
                                child: SizedBox(
                                  width: 160.w,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12.r),
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                Container(color: t.cardAlt, child: Icon(Icons.broken_image_outlined, color: t.textFaint)),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text('${fmtTime(m.capturedFrom, withDate: true)} · ${m.kind == 'frame' ? 'bản ghi' : 'trực tiếp'}',
                                          style: t.tiny),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      for (final v in videos)
                        Padding(
                          padding: EdgeInsets.only(top: 8.h),
                          child: Material(
                            color: t.cardAlt,
                            borderRadius: BorderRadius.circular(12.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.r),
                              onTap: () => openFleetVideo(context, FleetMonitoringService.mediaUrl(v.url),
                                  title: 'Video camera ${ev.vehicleCode}', subtitle: '${fmtTime(v.capturedFrom, withDate: true)} → ${fmtTime(v.capturedTo)}'),
                              child: Padding(
                                padding: EdgeInsets.all(10.w),
                                child: Row(children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.w,
                                    decoration: BoxDecoration(color: FxTokens.violet, borderRadius: BorderRadius.circular(10.r)),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('Video camera', style: t.h3),
                                      Text('${fmtTime(v.capturedFrom, withDate: true)} → ${fmtTime(v.capturedTo)}', style: t.tiny),
                                    ]),
                                  ),
                                  Icon(Icons.open_in_new_rounded, size: 18.sp, color: t.textMuted),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Review history
                if (ev.reviews.isNotEmpty)
                  FxCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FxSectionHeader(icon: Icons.history_rounded, title: 'Lịch sử duyệt', tone: FxTokens.blue),
                        for (var i = 0; i < ev.reviews.length; i++)
                          _ReviewItem(r: ev.reviews[i], last: i == ev.reviews.length - 1),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle(FxTokens t) => Center(
        child: Container(
          margin: EdgeInsets.only(bottom: 14.h, top: 4.h),
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(color: t.textFaint.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _camBtn(FxTokens t, IconData icon, String label, VoidCallback onTap) => Material(
        color: t.soft(FxTokens.violet),
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            child: Column(children: [
              Icon(icon, size: 20.sp, color: t.ink(FxTokens.violet)),
              SizedBox(height: 4.h),
              Text(label, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: t.ink(FxTokens.violet))),
            ]),
          ),
        ),
      );

  void _openGallery(BuildContext context, List<String> urls, int start) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _Gallery(urls: urls, start: start),
    ));
  }
}

class _ReviewItem extends StatelessWidget {
  final FleetReview r;
  final bool last;
  const _ReviewItem({required this.r, required this.last});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(children: [
            Container(width: 10, height: 10, margin: EdgeInsets.only(top: 4.h), decoration: const BoxDecoration(color: FxTokens.blue, shape: BoxShape.circle)),
            if (!last) Expanded(child: Container(width: 2, color: t.border)),
          ]),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(reviewLabel(r.label), style: t.h3),
                Text(fmtTime(r.ts, withDate: true), style: t.tiny),
                if (r.note.isNotEmpty) ...[SizedBox(height: 4.h), Text(r.note, style: t.small.copyWith(color: t.text))],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMap extends StatelessWidget {
  final double lat;
  final double lon;
  final Color color;
  const _MiniMap({required this.lat, required this.lon, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = LatLng(lat, lon);
    return FlutterMap(
      options: MapOptions(
        initialCenter: p,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
      ),
      children: [
        TileLayer(urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', userAgentPackageName: 'com.nguyenanh.nagapp'),
        CircleLayer(circles: [
          CircleMarker(point: p, radius: 40, useRadiusInMeter: true, color: color.withValues(alpha: 0.15), borderColor: color, borderStrokeWidth: 1),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: p,
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: Icon(Icons.location_on_rounded, color: color, size: 40, shadows: const [Shadow(color: Colors.black38, blurRadius: 4)]),
          ),
        ]),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  final List<String> urls;
  final int start;
  const _Gallery({required this.urls, required this.start});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _pc = PageController(initialPage: widget.start);
  late int _i = widget.start;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1} / ${widget.urls.length}', style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.network(widget.urls[i], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
