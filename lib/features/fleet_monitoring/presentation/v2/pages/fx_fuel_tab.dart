import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fuel_analysis.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_charts.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_event_sheet.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fx_vehicle_picker.dart';

/// "Nhiên liệu" (v2). Data loading, polling and baselines are the same as v1; only the presentation changed.
class FxFuelTab extends StatefulWidget {
  final ValueNotifier<String?> request;

  const FxFuelTab({super.key, required this.request});

  @override
  State<FxFuelTab> createState() => _FxFuelTabState();
}

enum _Preset { today, h24, d7, custom }

enum _Section { summary, journey, events }

enum _Metric { level, speed, rpm }

class _FxFuelTabState extends State<FxFuelTab> with AutomaticKeepAliveClientMixin {
  static const _storeKey = 'fleet-fuel-vehicle';
  static const _day = 86400;
  static const _liveGapS = 15 * 60;
  static const _perPage = 6;

  final _api = FleetMonitoringService();
  List<FleetVehicle> _vehicles = [];
  String? _vid;
  _Preset _preset = _Preset.today;
  DateTimeRange? _custom;
  FleetSeries? _series;
  List<FleetEvent> _events = [];
  List<FleetTrip> _trips = [];
  FuelSummary? _d7;
  FuelSummary? _d30;
  bool _loading = false;
  bool _vehiclesLoaded = false;
  String? _error;
  int _polls = 0;
  int _baseSeq = 0;
  int _loadSeq = 0;
  Timer? _timer;
  DateTime? _updatedAt;

  List<FuelRow> _rows = [];
  List<Phase> _phases = [];

  // presentation state
  _Section _section = _Section.summary;
  _Metric _metric = _Metric.level;
  int _timelinePage = 0;
  int _phasePage = 0;
  int _tripPage = 0;
  int _eventPage = 0;

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
    _timer?.cancel();
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
    try {
      final vs = await _api.vehicles();
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
      _restart();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được danh sách xe';
        });
      }
    }
  }

  void _setVehicle(String id) {
    setState(() => _vid = id);
    SharedPreferences.getInstance().then((p) => p.setString(_storeKey, id));
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timelinePage = _phasePage = _tripPage = _eventPage = 0;
    _load();
    if (_preset == _Preset.custom) return;
    _timer = Timer.periodic(Duration(seconds: _preset == _Preset.today ? 60 : 300), (_) => _load(quiet: true));
  }

  ({int from, int to}) _range() {
    final now = DateTime.now();
    if (_preset == _Preset.custom && _custom != null) {
      final s = _custom!.start, e = _custom!.end;
      return (from: toUnix(DateTime(s.year, s.month, s.day)), to: toUnix(DateTime(e.year, e.month, e.day, 23, 59, 59)));
    }
    if (_preset == _Preset.today) return (from: toUnix(DateTime(now.year, now.month, now.day)), to: toUnix(now));
    return (from: toUnix(now.subtract(Duration(hours: _preset == _Preset.h24 ? 24 : 24 * 7))), to: toUnix(now));
  }

  Future<void> _load({bool quiet = false}) async {
    final vid = _vid;
    if (vid == null) {
      setState(() => _loading = false);
      return;
    }
    final r = _range();
    final seq = ++_loadSeq;
    if (!quiet) {
      setState(() => _loading = true);
      _polls = 0;
    }
    final withTrips = !quiet || ++_polls % 5 == 0;
    if (!quiet) _loadBaselines(vid, r.from);
    try {
      final res = await Future.wait([
        _api.fuelSeries(vid, r.from, r.to, maxPoints: 1500),
        _api.fuelEvents(vehicleId: vid, from: r.from, to: r.to, limit: 100),
        withTrips ? _api.trips(vid, r.from, r.to).then<List<FleetTrip>?>((x) => x).catchError((_) => <FleetTrip>[]) : Future.value(null),
      ]);
      if (!mounted || seq != _loadSeq) return;
      final s = res[0] as FleetSeries;
      final rows = toRows(s);
      setState(() {
        _series = s;
        _rows = rows;
        _phases = derivePhases(rows);
        _events = res[1] as List<FleetEvent>;
        if (res[2] != null) _trips = res[2] as List<FleetTrip>;
        _error = null;
        _updatedAt = DateTime.now();
      });
    } catch (_) {
      if (mounted && seq == _loadSeq && !quiet) setState(() => _error = 'Không tải được dữ liệu nhiên liệu');
    } finally {
      if (mounted && seq == _loadSeq) setState(() => _loading = false);
    }
  }

  void _loadBaselines(String vid, int from) {
    final seq = ++_baseSeq;
    setState(() {
      _d7 = null;
      _d30 = null;
    });
    final f = fromUnix(from);
    final midnight = toUnix(DateTime(f.year, f.month, f.day));
    Future<FuelSummary?> win(int days) async {
      for (var attempt = 0; attempt <= 10; attempt++) {
        if (seq != _baseSeq || !mounted) return null;
        try {
          final x = await _api.fuelSummaryTotal(vid, midnight - days * _day, midnight);
          if (!x.partial) return x.total;
        } catch (_) {
          return null;
        }
        await Future.delayed(const Duration(seconds: 6));
      }
      return null;
    }

    Future.wait([win(7), win(30)]).then((v) {
      if (mounted && seq == _baseSeq) {
        setState(() {
          _d7 = v[0];
          _d30 = v[1];
        });
      }
    });
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _custom ?? DateTimeRange(start: now.subtract(const Duration(days: 1)), end: now),
    );
    if (r == null) return;
    setState(() {
      _custom = r;
      _preset = _Preset.custom;
    });
    _restart();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = FxTokens.of(context);
    final s = _series;

    final header = <Widget>[
      FxVehicleHeader(vehicles: _vehicles, selectedId: _vid, onChanged: _setVehicle),
      FxSegmented<_Preset>(
        segments: [
          const FxSegment(_Preset.today, 'Hôm nay'),
          const FxSegment(_Preset.h24, '24 giờ'),
          const FxSegment(_Preset.d7, '7 ngày'),
          FxSegment(_Preset.custom, 'Tùy chọn', icon: Icons.event_rounded),
        ],
        value: _preset,
        onChanged: (p) {
          if (p == _Preset.custom) {
            _pickCustom();
            return;
          }
          setState(() {
            _preset = p;
            _custom = null;
          });
          _restart();
        },
      ),
      Padding(padding: EdgeInsets.fromLTRB(4.w, 8.h, 4.w, 10.h), child: _statusLine(t)),
    ];

    if (_vehiclesLoaded && _vehicles.isEmpty) {
      return ListView(padding: EdgeInsets.all(14.w), children: const [
        FxEmpty(icon: Icons.local_shipping_outlined, title: 'Chưa có xe nào được giám sát'),
      ]);
    }
    if (s == null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
        children: [
          ...header,
          if (_error != null)
            FxEmpty(
              icon: Icons.cloud_off_rounded,
              title: _error!,
              action: FilledButton.icon(onPressed: () => _vehiclesLoaded ? _load() : _init(), icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
            )
          else ...[
            FxSkeleton(height: 150.h, radius: 18),
            SizedBox(height: 12.h),
            FxSkeleton(height: 260.h, radius: 18),
          ],
        ],
      );
    }

    final hasCan = s.sourcesCan > 0;
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 28.h),
        children: [
          ...header,
          if (!hasCan)
            FxBanner(
              title: 'Chưa có dữ liệu CAN',
              text: '${_vehicles.where((v) => v.fleetVehicleId == _vid).firstOrNull?.displayName ?? 'Xe này'} chưa gửi dữ liệu CAN trong khoảng này '
                  '(chưa lắp gateway hoặc mất kết nối). VTracking không có mức dầu nên chưa tính được tiêu hao.',
              icon: Icons.sensors_off_rounded,
            ),
          FxSegmented<_Section>(
            segments: [
              const FxSegment(_Section.summary, 'Tổng hợp', icon: Icons.insights_rounded),
              const FxSegment(_Section.journey, 'Hành trình', icon: Icons.route_rounded),
              FxSegment(_Section.events, 'Sự kiện', icon: Icons.warning_amber_rounded, badge: _events.length),
            ],
            value: _section,
            onChanged: (v) => setState(() => _section = v),
          ),
          SizedBox(height: 12.h),
          ...switch (_section) {
            _Section.summary => _summary(t, s, hasCan),
            _Section.journey => _journey(t, s),
            _Section.events => _eventsSection(t),
          },
        ],
      ),
    );
  }

  Widget _statusLine(FxTokens t) {
    final r = _range();
    final f = DateFormat('HH:mm dd/MM');
    final lastTs = _rows.isNotEmpty ? _rows.last.ts : null;
    final ended = _preset == _Preset.custom || (lastTs != null && toUnix(DateTime.now()) - lastTs > _liveGapS);
    final live = !ended && _series != null;
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 13.sp, color: t.textFaint),
        SizedBox(width: 4.w),
        Expanded(
          child: Text('${f.format(fromUnix(r.from))} → ${f.format(fromUnix(r.to))}',
              style: t.tiny.copyWith(fontFeatures: FxTokens.tabular), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (_loading)
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: t.textMuted))
        else if (_series != null)
          FxPill(
            label: live ? 'Đang chạy · ${_updatedAt != null ? DateFormat('HH:mm').format(_updatedAt!) : ''}' : 'Đã kết thúc',
            tone: live ? FxTokens.emerald : FxTokens.slate,
            dot: true,
          ),
      ],
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  List<Widget> _summary(FxTokens t, FleetSeries s, bool hasCan) {
    final sum = s.summary;
    final tank = s.tankCapacityL;
    final lvl = currentLevel(_rows);
    final l100 = sum.l100;
    final split = timeSplit(_phases);

    return [
      // Fuel hero
      FxCard(
        child: Column(
          children: [
            Row(
              children: [
                FxGauge(
                  value: lvl?.value,
                  size: 112.w,
                  stroke: 10,
                  color: lvl == null ? t.textFaint : (lvl.value < 20 ? FxTokens.red : FxTokens.emerald),
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(lvl == null ? '—' : fmtNum(lvl.value, 0), style: t.num(26.sp)),
                    Text('% bình', style: t.tiny),
                  ]),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mức nhiên liệu hiện tại', style: t.small),
                      SizedBox(height: 4.h),
                      Text(
                        lvl != null && tank != null ? '≈ ${fmtNum(lvl.value * tank / 100, 0)} L' : (lvl != null ? '${fmtNum(lvl.value, 1)} %' : '—'),
                        style: t.num(24.sp),
                      ),
                      if (tank != null) Text('trên ${fmtNum(tank, 0)} L dung tích bình', style: t.tiny),
                      SizedBox(height: 8.h),
                      if (lvl != null) FxPill(icon: Icons.access_time_rounded, label: 'Đọc lúc ${fmtUnix(lvl.ts)}', tone: FxTokens.slate),
                      SizedBox(height: 4.h),
                      Text('Mức xe báo qua CAN, chỉ đọc khi xe đứng yên', style: t.tiny),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      FxGrid(columns: 2, children: [
        FxKpi(
          icon: Icons.water_drop_outlined,
          label: 'Tiêu hao',
          value: fmtNum(sum.fuelUsedL, 1),
          unit: sum.fuelUncertaintyL != null && sum.fuelUncertaintyL! >= 0.5 ? 'L ±${fmtNum(sum.fuelUncertaintyL, 1)}' : 'L',
          tone: FxTokens.blue,
          hint: sum.fuelNote,
          footer: sum.fuelMovingL != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FxStackBar(height: 6, parts: [
                    (value: sum.fuelMovingL ?? 0, color: FxTokens.blue),
                    (value: sum.fuelStandingL ?? 0, color: FxTokens.amber),
                  ]),
                  SizedBox(height: 5.h),
                  Text('Chạy ${fmtNum(sum.fuelMovingL, 1)} · Đứng ${fmtNum(sum.fuelStandingL, 1)} L', style: t.tiny),
                ])
              : null,
        ),
        FxKpi(
          icon: Icons.speed_rounded,
          label: 'Tiêu hao trung bình',
          value: fmtNum(l100, 1),
          unit: 'L/100km',
          tone: FxTokens.amber,
          hint: sum.l100Reason ??
              (sum.lPer100km != null && sum.l100Kind == 'driving' ? 'Chỉ tính lúc xe chạy: ${fmtNum(sum.lPer100km, 1)} L/100km' : null),
          footer: FxDelta(cur: l100, base: _d7?.l100, label: 'vs TB 7 ngày'),
        ),
        FxKpi(icon: Icons.route_rounded, label: 'Quãng đường', value: fmtNum(sum.distanceKm, 1), unit: 'km', tone: FxTokens.violet),
        FxKpi(
          icon: Icons.engineering_outlined,
          label: 'Máy nổ / dừng nổ máy',
          value: fmtNum(sum.engineHours, 1),
          unit: 'h',
          sub: 'Dừng nổ máy ${fmtNum(sum.idleHours, 1)} h',
          tone: FxTokens.cyan,
        ),
      ]),
      _chartCard(t, s),
      _insightCard(t, l100, hasCan),
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FxSectionHeader(icon: Icons.donut_large_rounded, title: 'Cơ cấu thời gian', subtitle: 'Thời gian quan sát được trong khoảng đã chọn', tone: FxTokens.emerald),
            if (split.total <= 0)
              const FxEmpty(icon: Icons.hourglass_empty_rounded, title: 'Chưa có dữ liệu')
            else
              Builder(builder: (_) {
                final parts = [
                  (name: 'Di chuyển', value: split.moving, color: const Color(0xFF22C55E)),
                  (name: 'Dừng, nổ máy', value: split.standingOn, color: const Color(0xFFF59E0B)),
                  (name: 'Dừng, tắt máy', value: split.standingOff, color: const Color(0xFF94A3B8)),
                  (name: 'Dừng (không rõ)', value: split.unknown, color: const Color(0xFFCBD5E1)),
                ].where((p) => p.value > 0).toList();
                return Row(
                  children: [
                    FxDonut(parts: parts, centerValue: '${fmtNum(split.total / 3600, 1)} h', centerLabel: 'Tổng'),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        children: [
                          for (final p in parts)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 5.h),
                              child: Row(children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(3))),
                                SizedBox(width: 8.w),
                                Expanded(child: Text(p.name, style: t.small.copyWith(color: t.text))),
                                Text('${fmtNum(p.value / 3600, 1)} h', style: t.h3.copyWith(fontFeatures: FxTokens.tabular, fontSize: 12.sp)),
                                SizedBox(
                                  width: 40.w,
                                  child: Text('${fmtNum(p.value / split.total * 100, 0)}%',
                                      textAlign: TextAlign.right, style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FxSectionHeader(icon: Icons.bar_chart_rounded, title: 'So sánh tiêu hao', subtitle: 'L/100km · khoảng hiện tại so với trung bình', tone: FxTokens.blue),
            Builder(builder: (_) {
              final items = [
                (name: 'Hiện tại', v: l100, color: FxTokens.blue),
                (name: 'TB 7 ngày', v: _d7?.l100, color: const Color(0xFF60A5FA)),
                (name: 'TB 30 ngày', v: _d30?.l100, color: const Color(0xFF93C5FD)),
              ].where((x) => x.v != null).map((x) => (name: x.name, v: x.v!, color: x.color)).toList();
              if (items.isEmpty) {
                return FxEmpty(
                  icon: Icons.bar_chart_rounded,
                  title: _d7 == null && _d30 == null && l100 != null ? 'Đang tính trung bình 7 / 30 ngày…' : 'Chưa đủ dữ liệu để so sánh',
                );
              }
              return SizedBox(height: 200.h, child: Padding(padding: EdgeInsets.only(top: 16.h), child: FxCompareBars(items: items, unit: 'L/100km')));
            }),
          ],
        ),
      ),
      if (s.capabilities != null && hasCan) _capabilities(t, s.capabilities!),
    ];
  }

  Widget _chartCard(FxTokens t, FleetSeries s) {
    final pick = switch (_metric) {
      // realtime level so the line is continuous (the filtered level only exists while standing)
      _Metric.level => (FuelRow r) => r.levelRaw ?? r.level,
      _Metric.speed => (FuelRow r) => r.speed,
      _Metric.rpm => (FuelRow r) => r.rpm,
    };
    final color = switch (_metric) {
      _Metric.level => FxTokens.emerald,
      _Metric.speed => FxTokens.blue,
      _Metric.rpm => FxTokens.violet,
    };
    final unit = switch (_metric) {
      _Metric.level => '%',
      _Metric.speed => 'km/h',
      _Metric.rpm => 'rpm',
    };
    final vals = _rows.map(pick).whereType<double>().toList();
    final hasVals = vals.isNotEmpty;
    final mx = hasVals ? vals.reduce(math.max) : null;
    final avg = hasVals ? vals.reduce((a, b) => a + b) / vals.length : null;
    final last = hasVals ? vals.last : null;

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.show_chart_rounded,
            title: 'Biểu đồ theo thời gian',
            subtitle: 'Chạm và kéo trên biểu đồ để xem giá trị',
            tone: color,
          ),
          FxSegmented<_Metric>(
            dense: true,
            segments: const [
              FxSegment(_Metric.level, 'Mức dầu (%)'),
              FxSegment(_Metric.speed, 'Tốc độ'),
              FxSegment(_Metric.rpm, 'Vòng tua'),
            ],
            value: _metric,
            onChanged: (m) => setState(() => _metric = m),
          ),
          SizedBox(height: 12.h),
          Row(children: [
            _stat(t, _metric == _Metric.level ? 'Mới nhất' : 'Gần nhất', last, unit),
            _stat(t, 'Cao nhất', mx, unit),
            _stat(t, 'Trung bình', avg, unit),
          ]),
          SizedBox(height: 14.h),
          SizedBox(
            height: 230.h,
            child: FxTimeChart(
              key: ValueKey(_metric),
              rows: _rows,
              pick: pick,
              color: color,
              unit: unit,
              digits: _metric == _Metric.level ? 1 : 0,
              fixedMin: 0,
              fixedMax: _metric == _Metric.level ? 100 : null,
              yStep: _metric == _Metric.level ? 25 : null,
              bands: _metric == _Metric.level
                  ? [for (final p in _phases.where((p) => p.kind == PhaseKind.moving)) FxBand(p.from, p.to, FxTokens.green.withValues(alpha: 0.08))]
                  : const [],
              marks: [for (final e in s.events) FxMark(e.startTs, severityOf(e.severity).color)],
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(spacing: 14.w, runSpacing: 6.h, children: [
            FxLegend(color: color, label: _metric == _Metric.level ? 'Mức dầu (realtime)' : (_metric == _Metric.speed ? 'Tốc độ (km/h)' : 'Vòng tua (rpm)'), line: true),
            if (_metric == _Metric.level) FxLegend(color: FxTokens.green.withValues(alpha: 0.35), label: 'Xe đang chạy'),
            if (s.events.isNotEmpty) const FxLegend(color: FxTokens.red, label: 'Sự kiện nhiên liệu (!)', line: true),
          ]),
        ],
      ),
    );
  }

  Widget _stat(FxTokens t, String label, double? v, String unit) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: 6.w),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: t.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.tiny),
            SizedBox(height: 2.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: fmtNum(v, unit == '%' ? 1 : 0), style: t.num(15.sp)),
                if (v != null) TextSpan(text: ' $unit', style: t.tiny),
              ])),
            ),
          ]),
        ),
      );

  Widget _insightCard(FxTokens t, double? l100, bool hasCan) {
    final notes = <(IconData, Color, String)>[];
    final b7 = _d7?.l100;
    final sum = _series?.summary;
    if (l100 != null && b7 != null && b7 > 0) {
      final pct = (l100 - b7) / b7 * 100;
      notes.add((
        pct >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
        pct >= 10 ? FxTokens.red : (pct >= 0 ? FxTokens.amber : FxTokens.emerald),
        'Tiêu hao ${fmtNum(l100, 1)} L/100km, ${pct >= 0 ? 'cao' : 'thấp'} hơn ${fmtNum(pct.abs(), 0)}% so với trung bình 7 ngày trước (${fmtNum(b7, 1)} L/100km).'
      ));
    } else if (l100 != null) {
      notes.add((Icons.info_outline_rounded, FxTokens.slate, 'Tiêu hao ${fmtNum(l100, 1)} L/100km. Chưa đủ dữ liệu 7 ngày trước để so sánh.'));
    }
    if (sum?.fuelUsedL != null && sum!.fuelUsedL! > 0 && sum.fuelStandingL != null) {
      notes.add((
        Icons.hourglass_bottom_rounded,
        FxTokens.amber,
        'Dầu đốt lúc đứng nổ máy (quay bồn / chờ) ${fmtNum(sum.fuelStandingL, 1)} L, chiếm ${fmtNum(sum.fuelStandingL! / sum.fuelUsedL! * 100, 0)}% tổng tiêu hao.'
      ));
    }
    if (_events.isNotEmpty) {
      final ev = [...(_series?.events ?? <FleetSeriesEvent>[])]..sort((a, b) => (b.deltaPct ?? 0).abs().compareTo((a.deltaPct ?? 0).abs()));
      final worst = ev.firstOrNull;
      notes.add((
        Icons.warning_amber_rounded,
        FxTokens.red,
        'Có ${_events.length} sự kiện nhiên liệu cần rà soát${worst != null ? '; lớn nhất: ${worst.title} lúc ${fmtUnix(worst.startTs)}' : ''}. Xem ở mục Sự kiện.'
      ));
    } else if (hasCan) {
      notes.add((Icons.verified_outlined, FxTokens.emerald, 'Không có sự kiện nhiên liệu bất thường trong khoảng này.'));
    }
    if (notes.isEmpty) return const SizedBox.shrink();
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FxSectionHeader(icon: Icons.lightbulb_outline_rounded, title: 'Ghi chú & phân tích', tone: FxTokens.amber),
          for (final n in notes)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(5.w),
                    decoration: BoxDecoration(color: t.soft(n.$2), borderRadius: BorderRadius.circular(8.r)),
                    child: Icon(n.$1, size: 14.sp, color: t.ink(n.$2)),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(child: Text(n.$3, style: t.body.copyWith(fontSize: 12.5.sp))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _capabilities(FxTokens t, FleetCapabilities c) {
    final ok = c.signals.values.where((s) => s.state == 'ok').length;
    return FxCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
          childrenPadding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
          leading: const FxIconBadge(icon: Icons.sensors_rounded, tone: FxTokens.cyan, size: 32),
          title: Text('Chất lượng dữ liệu CAN', style: t.h2),
          subtitle: Text('$ok/${c.signals.length} tín hiệu tốt${c.suspect.isNotEmpty ? ' · ${c.suspect.length} đáng ngờ' : ''}', style: t.tiny),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final e in c.signals.entries)
                  FxPill(
                    icon: e.value.state == 'ok'
                        ? Icons.check_rounded
                        : e.value.state == 'suspect'
                            ? Icons.priority_high_rounded
                            : Icons.close_rounded,
                    label: e.value.label,
                    tone: e.value.state == 'ok' ? FxTokens.emerald : (e.value.state == 'suspect' ? FxTokens.red : FxTokens.slate),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            _kv(t, 'Cách tính tiêu hao', c.fuelLabel),
            _kv(t, 'Quãng đường', c.distanceLabel),
            _kv(t, 'Xe chạy / dừng', c.motionLabel),
            _kv(t, 'Nổ máy', c.engineLabel),
            if (c.suspect.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: FxBanner(
                  tone: FxTokens.red,
                  icon: Icons.report_gmailerrorred_rounded,
                  text: 'Tín hiệu đáng ngờ: ${c.suspect.map((k) => c.signals[k]?.label ?? k).join(', ')} — không nên tin số liệu liên quan.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(FxTokens t, String k, String v) => Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120.w, child: Text(k, style: t.small)),
          Expanded(child: Text(v.isEmpty ? '—' : v, style: t.small.copyWith(color: t.text, fontWeight: FontWeight.w600))),
        ]),
      );

  // ── Journey ──────────────────────────────────────────────────────────────

  List<Widget> _journey(FxTokens t, FleetSeries s) {
    final lastTs = _rows.isNotEmpty ? _rows.last.ts : null;
    final ended = _preset == _Preset.custom || (lastTs != null && toUnix(DateTime.now()) - lastTs > _liveGapS);

    // timeline (same rules as v1)
    final items = <({int ts, String kind, String title, String? sub, String? severity, String? eventId})>[];
    var seenMove = false;
    for (final p in _phases) {
      if (p.kind == PhaseKind.moving) {
        items.add((ts: p.from, kind: 'move', title: seenMove ? 'Tiếp tục di chuyển' : 'Bắt đầu di chuyển', sub: null, severity: null, eventId: null));
        seenMove = true;
      } else if (p.to - p.from >= 120) {
        items.add((ts: p.from, kind: 'stop', title: 'Dừng xe', sub: '${kPhaseLabel[p.kind]} · ${fmtDur(p.to - p.from)}', severity: null, eventId: null));
      }
    }
    for (final e in _events) {
      final d = parseTime(e.startedAt);
      if (d == null) continue;
      items.add((ts: toUnix(d), kind: 'event', title: e.title, sub: e.reason, severity: e.severity, eventId: e.id));
    }
    if (ended && lastTs != null) items.add((ts: lastTs, kind: 'end', title: 'Dữ liệu cuối cùng', sub: null, severity: null, eventId: null));
    items.sort((a, b) => a.ts.compareTo(b.ts));

    final phases = _phases.where((p) => p.to - p.from >= 30).toList();
    final timelinePage = fxPage(items, _timelinePage, 8);
    final phasePage = fxPage(phases, _phasePage, _perPage);
    final tripPage = fxPage(_trips, _tripPage, _perPage);
    final phaseOffset = _phasePage.clamp(0, math.max(0, (phases.length / _perPage).ceil() - 1)).toInt() * _perPage;

    return [
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxSectionHeader(icon: Icons.timeline_rounded, title: 'Diễn biến trong ngày', subtitle: '${items.length} mốc', tone: FxTokens.blue),
            if (items.isEmpty)
              const FxEmpty(icon: Icons.timeline_rounded, title: 'Chưa có diễn biến')
            else ...[
              for (var i = 0; i < timelinePage.length; i++) _timelineRow(t, timelinePage[i], i == timelinePage.length - 1),
              FxPager(page: _timelinePage, total: items.length, size: 8, onChanged: (p) => setState(() => _timelinePage = p)),
            ],
          ],
        ),
      ),
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxSectionHeader(
              icon: Icons.alt_route_rounded,
              title: 'Chi tiết hành trình & tiêu hao',
              subtitle: '${phases.length} đoạn · chạy / dừng nổ máy / tắt máy',
              tone: FxTokens.violet,
            ),
            if (phases.isEmpty)
              const FxEmpty(icon: Icons.alt_route_rounded, title: 'Chưa có dữ liệu hành trình')
            else ...[
              for (var i = 0; i < phasePage.length; i++) _phaseRow(t, phasePage[i], phaseOffset + i + 1),
              FxPager(page: _phasePage, total: phases.length, size: _perPage, onChanged: (p) => setState(() => _phasePage = p)),
            ],
          ],
        ),
      ),
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxSectionHeader(icon: Icons.receipt_long_rounded, title: 'Tiêu hao theo chuyến', subtitle: '${_trips.length} chuyến', tone: FxTokens.emerald),
            if (_trips.isEmpty)
              const FxEmpty(icon: Icons.receipt_long_rounded, title: 'Không có chuyến trong khoảng này')
            else ...[
              for (final tr in tripPage) _tripRow(t, tr),
              FxPager(page: _tripPage, total: _trips.length, size: _perPage, onChanged: (p) => setState(() => _tripPage = p)),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _timelineRow(FxTokens t, ({int ts, String kind, String title, String? sub, String? severity, String? eventId}) it, bool last) {
    final hot = it.kind == 'event';
    final color = hot
        ? severityOf(it.severity ?? 'notable').color
        : it.kind == 'move'
            ? FxTokens.green
            : it.kind == 'stop'
                ? FxTokens.amber
                : FxTokens.slate;
    final icon = hot
        ? Icons.warning_amber_rounded
        : it.kind == 'move'
            ? Icons.play_arrow_rounded
            : it.kind == 'stop'
                ? Icons.pause_rounded
                : Icons.stop_rounded;
    return InkWell(
      onTap: it.eventId == null ? null : () => showFxEventSheet(context, eventId: it.eventId!, category: 'fuel'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44.w,
              child: Padding(
                padding: EdgeInsets.only(top: 6.h),
                child: Text(fmtUnix(it.ts), style: t.tiny.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular)),
              ),
            ),
            Column(children: [
              Container(
                width: 26.w,
                height: 26.w,
                decoration: BoxDecoration(color: t.soft(color), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.5))),
                child: Icon(icon, size: 14.sp, color: t.ink(color)),
              ),
              if (!last) Expanded(child: Container(width: 2, color: t.border)),
            ]),
            SizedBox(width: 10.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4.h, bottom: 14.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(it.title, style: t.h3.copyWith(fontSize: 13.sp, color: hot ? t.ink(color) : t.text))),
                      if (hot) Icon(Icons.chevron_right_rounded, size: 18.sp, color: t.textFaint),
                    ]),
                    if (it.sub != null) ...[
                      SizedBox(height: 2.h),
                      Text(it.sub!, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _phaseRow(FxTokens t, Phase p, int no) {
    final c = p.kind == PhaseKind.moving
        ? FxTokens.green
        : p.kind == PhaseKind.standingOn
            ? FxTokens.amber
            : FxTokens.slate;
    Widget metric(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.tiny),
            SizedBox(height: 2.h),
            Text(value, style: t.h3.copyWith(fontSize: 12.5.sp, fontFeatures: FxTokens.tabular)),
          ]),
        );
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.horizontal(left: Radius.circular(12.r))),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('#$no', style: t.tiny.copyWith(fontWeight: FontWeight.w800)),
                      SizedBox(width: 8.w),
                      Text('${fmtUnix(p.from)} – ${fmtUnix(p.to)}', style: t.h3.copyWith(fontFeatures: FxTokens.tabular)),
                      SizedBox(width: 6.w),
                      Text(fmtDur(p.to - p.from), style: t.tiny),
                      const Spacer(),
                      FxPill(label: kPhaseLabel[p.kind]!, tone: c),
                    ]),
                    SizedBox(height: 8.h),
                    Row(children: [
                      metric('Quãng đường', fmtNum(p.distanceKm, 1, 'km')),
                      metric('Tiêu hao', fmtNum(p.fuelL, 1, 'L')),
                      metric('L/100km', p.kind == PhaseKind.moving ? fmtNum(p.l100, 1) : '—'),
                    ]),
                    if (p.levelStart != null || p.levelEnd != null) ...[
                    SizedBox(height: 6.h),
                    Row(children: [
                      Icon(Icons.local_gas_station_outlined, size: 13.sp, color: t.textFaint),
                      SizedBox(width: 4.w),
                      Text('Mức dầu ${fmtNum(p.levelStart, 1)}%', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                      Icon(Icons.arrow_right_alt_rounded, size: 16.sp, color: t.textFaint),
                      Text('${fmtNum(p.levelEnd, 1)}%', style: t.tiny.copyWith(fontFeatures: FxTokens.tabular, color: t.text, fontWeight: FontWeight.w700)),
                    ]),
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

  Widget _tripRow(FxTokens t, FleetTrip tr) {
    final delivery = tr.purpose == 'delivery';
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: t.border)),
      child: Row(
        children: [
          FxIconBadge(icon: delivery ? Icons.local_shipping_rounded : Icons.u_turn_left_rounded, tone: delivery ? FxTokens.blue : FxTokens.slate, size: 34),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Chuyến #${tr.orderNumber ?? '—'}', style: t.h3),
                  SizedBox(width: 6.w),
                  FxPill(label: delivery ? 'Giao hàng' : 'Không lấy hàng', tone: delivery ? FxTokens.blue : FxTokens.slate),
                ]),
                SizedBox(height: 3.h),
                Text('${fmtTime(tr.startedAt)} → ${tr.endedAt != null ? fmtTime(tr.endedAt) : 'đang chạy'}',
                    style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtNum(tr.fuel.fuelUsedL, 1, 'L'), style: t.num(15.sp)),
              Text(fmtNum(tr.fuel.distanceKm, 1, 'km'), style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Events ───────────────────────────────────────────────────────────────

  List<Widget> _eventsSection(FxTokens t) {
    final page = fxPage(_events, _eventPage, _perPage);
    return [
      FxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FxSectionHeader(
              icon: Icons.warning_amber_rounded,
              title: 'Sự kiện nhiên liệu bất thường',
              subtitle: 'Chạm vào sự kiện để xem bằng chứng',
              tone: FxTokens.red,
              trailing: FxPill(label: '${_events.length}', tone: _events.isEmpty ? FxTokens.emerald : FxTokens.red, solid: _events.isNotEmpty),
            ),
            if (_events.isEmpty)
              const FxEmpty(icon: Icons.verified_outlined, title: 'Không có sự kiện bất thường', message: 'Mức nhiên liệu ổn định trong khoảng này.')
            else ...[
              for (final e in page) _eventRow(t, e),
              FxPager(page: _eventPage, total: _events.length, size: _perPage, onChanged: (p) => setState(() => _eventPage = p)),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _eventRow(FxTokens t, FleetEvent e) {
    final tone = severityOf(e.severity);
    num? n(String k) => e.evidence[k] is num ? e.evidence[k] as num : null;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () => showFxEventSheet(context, eventId: e.id, category: 'fuel'),
          child: Container(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 6.w, 10.h),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r), border: Border(left: BorderSide(color: tone.color, width: 4))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(e.title, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        FxPill(label: tone.label, tone: tone.color),
                      ]),
                      SizedBox(height: 4.h),
                      Text(e.reason, style: t.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 4.h),
                      Row(children: [
                        Icon(Icons.schedule_rounded, size: 12.sp, color: t.textFaint),
                        SizedBox(width: 3.w),
                        Text(fmtTime(e.startedAt, withDate: true), style: t.tiny.copyWith(fontFeatures: FxTokens.tabular)),
                        if (n('delta_pct') != null) ...[
                          SizedBox(width: 10.w),
                          Icon(Icons.trending_down_rounded, size: 12.sp, color: t.ink(FxTokens.red)),
                          SizedBox(width: 3.w),
                          Text('${fmtNum(n('delta_pct'), 1)}%${n('drop_l') != null ? ' ≈ ${fmtNum(n('drop_l'), 0)} L' : ''}',
                              style: t.tiny.copyWith(color: t.ink(FxTokens.red), fontWeight: FontWeight.w700)),
                        ],
                      ]),
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
}
