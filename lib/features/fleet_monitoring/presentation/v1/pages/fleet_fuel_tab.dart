import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fuel_analysis.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_charts.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_common.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_event_sheet.dart';

/// "Nhiên liệu" — port of FuelMonitor.tsx (CAN fuel level, consumption, phases, events, trips).
class FleetFuelTab extends StatefulWidget {
  /// Set by the overview ("Dầu" button) to open a given vehicle.
  final ValueNotifier<String?> request;

  const FleetFuelTab({super.key, required this.request});

  @override
  State<FleetFuelTab> createState() => _FleetFuelTabState();
}

enum _Preset { today, h24, d7, custom }

class _FleetFuelTabState extends State<FleetFuelTab> with AutomaticKeepAliveClientMixin {
  static const _storeKey = 'fleet-fuel-vehicle';
  static const _day = 86400;
  static const _liveGapS = 15 * 60;

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
  String? _error;
  int _polls = 0;
  int _baseSeq = 0;
  int _loadSeq = 0;
  Timer? _timer;

  // derived
  List<FuelRow> _rows = [];
  List<Phase> _phases = [];

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
    _load();
    if (_preset == _Preset.custom) return; // a past range does not change: no polling
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
    final withTrips = !quiet || ++_polls % 5 == 0; // trips change slowly
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
      });
    } catch (_) {
      if (mounted && seq == _loadSeq && !quiet) setState(() => _error = 'Không tải được dữ liệu nhiên liệu');
    } finally {
      if (mounted && seq == _loadSeq) setState(() => _loading = false);
    }
  }

  /// Whole-day reference windows ending at this period's midnight; the server answers "partial" until ready.
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final s = _series;
    final sum = s?.summary;
    final tank = s?.tankCapacityL;
    final hasCan = (s?.sourcesCan ?? 0) > 0;
    final lvl = currentLevel(_rows);
    final lastTs = _rows.isNotEmpty ? _rows.last.ts : null;
    final ended = _preset == _Preset.custom || (lastTs != null && toUnix(DateTime.now()) - lastTs > _liveGapS);
    final cur = _vehicles.where((v) => v.fleetVehicleId == _vid).firstOrNull;
    final l100 = sum?.l100;
    final split = timeSplit(_phases);

    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          VehiclePickerField(vehicles: _vehicles, selectedId: _vid, onChanged: _setVehicle),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: SegmentChips<_Preset>(
                  options: const [(_Preset.today, 'Hôm nay'), (_Preset.h24, '24 giờ'), (_Preset.d7, '7 ngày')],
                  value: _preset,
                  onChanged: (p) {
                    setState(() {
                      _preset = p;
                      _custom = null;
                    });
                    _restart();
                  },
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(
                  _preset == _Preset.custom && _custom != null
                      ? '${DateFormat('dd/MM').format(_custom!.start)}–${DateFormat('dd/MM').format(_custom!.end)}'
                      : 'Tùy chọn',
                  style: TextStyle(fontSize: 12.sp),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor: _preset == _Preset.custom ? cs.secondaryContainer : null,
                onPressed: _pickCustom,
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2) else SizedBox(height: 2.h),
          SizedBox(height: 10.h),
          if (_error != null && s == null) FleetNotice(_error!, color: const Color(0xFFDC2626)),
          if (_vehicles.isEmpty && !_loading) const FleetEmpty('Không có xe'),
          if (s != null && !hasCan)
            FleetNotice('${cur?.displayName ?? ''} chưa gửi dữ liệu CAN trong khoảng này (chưa lắp gateway hoặc gateway mất kết nối). '
                'VTracking không có mức dầu nên chưa tính được tiêu hao. Trang tự cập nhật mỗi phút.'),
          if (s?.capabilities != null && hasCan) _capabilities(s!.capabilities!),
          if (s != null) ...[
            KpiGrid(children: [
              KpiTile(
                icon: Icons.local_gas_station_rounded,
                label: 'Mức nhiên liệu hiện tại',
                value: lvl != null ? fmtNum(lvl.value, 1, '%') : '—',
                sub: lvl != null
                    ? '${tank != null ? '≈ ${fmtNum(lvl.value * tank / 100, 0)} / ${fmtNum(tank, 0)} L · ' : ''}lúc ${fmtUnix(lvl.ts)}'
                    : null,
                hint: 'Mức xe báo về qua CAN, chỉ đọc khi xe đứng yên',
                color: const Color(0xFF059669),
              ),
              KpiTile(
                icon: Icons.show_chart_rounded,
                label: 'Tiêu hao',
                value:
                    '${fmtNum(sum?.fuelUsedL, 1, 'L')}${sum?.fuelUncertaintyL != null && sum!.fuelUncertaintyL! >= 0.5 ? ' ±${fmtNum(sum.fuelUncertaintyL, 1)}' : ''}',
                sub: sum?.fuelMovingL != null
                    ? 'Chạy ${fmtNum(sum!.fuelMovingL, 1)} L · đứng nổ máy ${fmtNum(sum.fuelStandingL, 1)} L'
                    : null,
                hint: sum?.fuelNote,
                color: const Color(0xFF2563EB),
              ),
              KpiTile(icon: Icons.route_rounded, label: 'Quãng đường', value: fmtNum(sum?.distanceKm, 1, 'km'), color: const Color(0xFF7C3AED)),
              KpiTile(
                icon: Icons.speed_rounded,
                label: 'Tiêu hao TB',
                value: l100 == null ? '—' : '${fmtNum(l100, 1)} L/100km',
                badge: _delta(l100, _d7?.l100, 'so với TB 7 ngày'),
                hint: sum?.l100Reason ??
                    (sum?.lPer100km != null && sum?.l100Kind == 'driving'
                        ? 'Chỉ tính lúc xe chạy: ${fmtNum(sum!.lPer100km, 1)} L/100km'
                        : null),
                color: const Color(0xFFD97706),
              ),
              KpiTile(icon: Icons.schedule_rounded, label: 'Thời gian máy nổ', value: fmtNum(sum?.engineHours, 1, 'h'), color: const Color(0xFF0891B2)),
              KpiTile(icon: Icons.timer_outlined, label: 'Dừng nổ máy', value: fmtNum(sum?.idleHours, 1, 'h'), color: const Color(0xFFCA8A04)),
            ]),
            FleetSection(
              title: 'Mức nhiên liệu (%)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 200.h,
                    child: FleetLineChart(
                      rows: _rows,
                      pick: (r) => r.level,
                      color: const Color(0xFF16A34A),
                      unit: '%',
                      minY: 0,
                      maxY: 100,
                      filled: true,
                      marks: [for (final e in s.events) (ts: e.startTs, color: severityOf(e.severity).color)],
                    ),
                  ),
                  if (s.events.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Text('Vạch đứt: sự kiện nhiên liệu', style: TextStyle(fontSize: 10.sp, color: cs.outline)),
                    ),
                ],
              ),
            ),
            FleetSection(title: 'Sự kiện trong ngày', child: _timeline(ended, lastTs)),
            FleetSection(
              title: 'Tốc độ (km/h)',
              child: SizedBox(
                height: 150.h,
                child: FleetLineChart(rows: _rows, pick: (r) => r.speed, color: const Color(0xFF2563EB), unit: 'km/h', minY: 0),
              ),
            ),
            FleetSection(
              title: 'Vòng tua máy (rpm)',
              child: SizedBox(
                height: 150.h,
                child: FleetLineChart(rows: _rows, pick: (r) => r.rpm, color: const Color(0xFF7C3AED), unit: 'rpm', minY: 0),
              ),
            ),
            FleetSection(title: 'Tiêu hao trung bình (L/100km)', child: _compare(l100)),
            FleetSection(
              title: 'Cơ cấu thời gian',
              child: split.total <= 0
                  ? const FleetEmpty('Chưa có dữ liệu')
                  : TimeSplitDonut(
                      total: split.total,
                      parts: [
                        (name: 'Di chuyển', value: split.moving, color: const Color(0xFF22C55E)),
                        (name: 'Dừng, nổ máy', value: split.standingOn, color: const Color(0xFFFBBF24)),
                        (name: 'Dừng, tắt máy', value: split.standingOff, color: const Color(0xFF94A3B8)),
                        (name: 'Dừng (không rõ)', value: split.unknown, color: const Color(0xFFCBD5E1)),
                      ].where((p) => p.value > 0).toList(),
                    ),
            ),
            FleetSection(title: 'Chi tiết hành trình & tiêu hao', child: _phaseList()),
            FleetSection(
              title: 'Ghi chú & phân tích',
              trailing: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 18),
              child: _notes(l100, hasCan),
            ),
            FleetSection(title: 'Sự kiện nhiên liệu bất thường (${_events.length})', child: _eventList()),
            FleetSection(title: 'Tiêu hao theo chuyến', child: _tripList()),
          ],
        ],
      ),
    );
  }

  Widget? _delta(double? cur, double? base, String label) {
    if (cur == null || base == null || base <= 0) return null;
    final pct = (cur - base) / base * 100;
    if (!pct.isFinite) return null;
    final up = pct >= 0;
    final c = pct >= 10
        ? const Color(0xFFDC2626)
        : up
            ? const Color(0xFFB45309)
            : const Color(0xFF047857);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6.r)),
      child: Text('${up ? '↑ +' : '↓ '}${fmtNum(pct, 0)}% $label', style: TextStyle(fontSize: 10.sp, color: c, fontWeight: FontWeight.w600)),
    );
  }

  Widget _capabilities(FleetCapabilities c) {
    final cs = Theme.of(context).colorScheme;
    return FleetSection(
      title: 'Dữ liệu xe này gửi về',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final e in c.signals.entries)
                ToneChip(
                  label: '${e.value.state == 'ok' ? '✓' : e.value.state == 'suspect' ? '!' : '✕'} ${e.value.label}',
                  color: e.value.state == 'ok'
                      ? const Color(0xFF047857)
                      : e.value.state == 'suspect'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF94A3B8),
                  dense: true,
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Cách tính tiêu hao: ${c.fuelLabel} · Quãng đường: ${c.distanceLabel} · Xe chạy/dừng: ${c.motionLabel} · Nổ máy: ${c.engineLabel}',
            style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant, height: 1.35),
          ),
          if (c.suspect.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Tín hiệu đáng ngờ: ${c.suspect.map((k) => c.signals[k]?.label ?? k).join(', ')} — không nên tin số liệu liên quan.',
                style: TextStyle(fontSize: 11.sp, color: const Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeline(bool ended, int? lastTs) {
    final items = <({int ts, String kind, String title, String? sub, String? severity, String? eventId})>[];
    var seenMove = false;
    for (final p in _phases) {
      if (p.kind == PhaseKind.moving) {
        items.add((ts: p.from, kind: 'move', title: seenMove ? 'Tiếp tục di chuyển' : 'Bắt đầu di chuyển', sub: null, severity: null, eventId: null));
        seenMove = true;
      } else if (p.to - p.from >= 120) {
        items.add((
          ts: p.from,
          kind: 'stop',
          title: 'Dừng xe',
          sub: '${kPhaseLabel[p.kind]} · ${fmtDur(p.to - p.from)}',
          severity: null,
          eventId: null
        ));
      }
    }
    for (final e in _events) {
      final d = parseTime(e.startedAt);
      if (d == null) continue;
      items.add((ts: toUnix(d), kind: 'event', title: e.title, sub: e.reason, severity: e.severity, eventId: e.id));
    }
    if (ended && lastTs != null) items.add((ts: lastTs, kind: 'end', title: 'Dữ liệu cuối cùng', sub: null, severity: null, eventId: null));
    items.sort((a, b) => a.ts.compareTo(b.ts));
    if (items.isEmpty) return const FleetEmpty('Chưa có sự kiện');
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 340.h),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final t = items[i];
          final hot = t.kind == 'event';
          final color = hot
              ? severityOf(t.severity ?? 'notable').color
              : t.kind == 'move'
                  ? const Color(0xFF16A34A)
                  : t.kind == 'stop'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF64748B);
          final icon = hot
              ? Icons.warning_amber_rounded
              : t.kind == 'move'
                  ? Icons.play_arrow_rounded
                  : Icons.stop_rounded;
          return InkWell(
            onTap: t.eventId == null ? null : () => showFleetEventSheet(context, eventId: t.eventId!, category: 'fuel'),
            borderRadius: BorderRadius.circular(8.r),
            child: Container(
              margin: EdgeInsets.only(bottom: 4.h),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: hot ? const Color(0xFFDC2626).withValues(alpha: 0.06) : null,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16.sp, color: color),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title, style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600)),
                        if (t.sub != null)
                          Text(t.sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(fmtUnix(t.ts), style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _compare(double? l100) {
    final items = [
      (name: 'Phiên hiện tại', v: l100, color: const Color(0xFF2563EB)),
      (name: 'TB 7 ngày', v: _d7?.l100, color: const Color(0xFF93C5FD)),
      (name: 'TB 30 ngày', v: _d30?.l100, color: const Color(0xFFBFDBFE)),
    ].where((x) => x.v != null).map((x) => (name: x.name, v: x.v!, color: x.color)).toList();
    if (items.isEmpty) return const FleetEmpty('Chưa đủ dữ liệu để so sánh');
    return CompareBars(items: items, unit: 'L/100km');
  }

  Widget _phaseList() {
    final list = _phases.where((p) => p.to - p.from >= 30).toList();
    if (list.isEmpty) return const FleetEmpty('Chưa có dữ liệu hành trình');
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          Builder(builder: (_) {
            final p = list[i];
            final c = p.kind == PhaseKind.moving
                ? const Color(0xFF16A34A)
                : p.kind == PhaseKind.standingOn
                    ? const Color(0xFFCA8A04)
                    : const Color(0xFF64748B);
            return Container(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)))),
              child: Row(
                children: [
                  SizedBox(width: 22.w, child: Text('${i + 1}', style: TextStyle(fontSize: 11.sp, color: cs.outline))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${fmtUnix(p.from)} – ${fmtUnix(p.to)}', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                            SizedBox(width: 6.w),
                            ToneChip(label: kPhaseLabel[p.kind]!, color: c, dense: true),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Quãng đường ${fmtNum(p.distanceKm, 1, 'km')} · Mức ${fmtNum(p.levelStart, 1)}% → ${fmtNum(p.levelEnd, 1)}%'
                          ' · Tiêu hao ${fmtNum(p.fuelL, 1, 'L')}${p.kind == PhaseKind.moving ? ' · ${fmtNum(p.l100, 1)} L/100km' : ''}',
                          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _notes(double? l100, bool hasCan) {
    final notes = <String>[];
    final b7 = _d7?.l100;
    final sum = _series?.summary;
    if (l100 != null && b7 != null && b7 > 0) {
      final pct = (l100 - b7) / b7 * 100;
      notes.add('Tiêu hao ${fmtNum(l100, 1)} L/100km, ${pct >= 0 ? 'cao' : 'thấp'} hơn ${fmtNum(pct.abs(), 0)}% so với trung bình 7 ngày trước (${fmtNum(b7, 1)} L/100km).');
    } else if (l100 != null) {
      notes.add('Tiêu hao ${fmtNum(l100, 1)} L/100km. Chưa đủ dữ liệu 7 ngày trước để so sánh.');
    }
    if (sum?.fuelUsedL != null && sum!.fuelUsedL! > 0 && sum.fuelStandingL != null) {
      notes.add('Dầu đốt lúc đứng nổ máy (quay bồn / chờ) ${fmtNum(sum.fuelStandingL, 1)} L, chiếm ${fmtNum(sum.fuelStandingL! / sum.fuelUsedL! * 100, 0)}% tổng tiêu hao.');
    }
    if (_events.isNotEmpty) {
      final ev = [...(_series?.events ?? <FleetSeriesEvent>[])]..sort((a, b) => (b.deltaPct ?? 0).abs().compareTo((a.deltaPct ?? 0).abs()));
      final worst = ev.firstOrNull;
      notes.add('Có ${_events.length} sự kiện nhiên liệu cần rà soát${worst != null ? '; lớn nhất: ${worst.title} lúc ${fmtUnix(worst.startTs)}' : ''}. Bấm vào sự kiện để xem bằng chứng.');
    } else if (hasCan) {
      notes.add('Không có sự kiện nhiên liệu bất thường trong khoảng này.');
    }
    if (notes.isEmpty) return const FleetEmpty('Chưa có dữ liệu để phân tích.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in notes)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: TextStyle(fontSize: 13.sp)),
                Expanded(child: Text(n, style: TextStyle(fontSize: 12.5.sp, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _eventList() {
    if (_events.isEmpty) return const FleetEmpty('Không có sự kiện', icon: Icons.check_circle_outline_rounded);
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final e in _events)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.title, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
            subtitle: Text(fmtTime(e.startedAt, withDate: true), style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
            trailing: ToneChip(label: severityOf(e.severity).label, color: severityOf(e.severity).color, dense: true),
            onTap: () => showFleetEventSheet(context, eventId: e.id, category: 'fuel'),
          ),
      ],
    );
  }

  Widget _tripList() {
    if (_trips.isEmpty) return const FleetEmpty('Không có chuyến');
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final t in _trips)
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${t.orderNumber ?? '—'}', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800)),
                          SizedBox(width: 6.w),
                          ToneChip(
                            label: t.purpose == 'delivery' ? 'Giao hàng' : 'Không lấy hàng',
                            color: t.purpose == 'delivery' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                            dense: true,
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text('${fmtTime(t.startedAt)} → ${t.endedAt != null ? fmtTime(t.endedAt) : '…'}',
                          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtNum(t.fuel.fuelUsedL, 1, 'L'), style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                    Text(fmtNum(t.fuel.distanceKm, 1, 'km'), style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
