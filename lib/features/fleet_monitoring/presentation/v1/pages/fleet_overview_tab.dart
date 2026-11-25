import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/services/fleet_monitoring_service.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_common.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_event_sheet.dart';

/// "Tổng quan" — port of FleetOverview.tsx: KPIs, map, open alerts, vehicle list. Refreshes every 30 s.
class FleetOverviewTab extends StatefulWidget {
  final FleetPermissions perms;
  final ValueChanged<String>? onOpenFuel;
  final ValueChanged<String>? onOpenConcrete;

  const FleetOverviewTab({super.key, required this.perms, this.onOpenFuel, this.onOpenConcrete});

  @override
  State<FleetOverviewTab> createState() => _FleetOverviewTabState();
}

class _FleetOverviewTabState extends State<FleetOverviewTab> with AutomaticKeepAliveClientMixin {
  final _api = FleetMonitoringService();
  final _map = MapController();
  FleetOverview? _data;
  bool _loading = false;
  String? _error;
  String _q = '';
  String _only = 'all';
  String? _selected;
  Timer? _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() => _loading = true);
    try {
      final d = await _api.overview(fuelDays: 7);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (mounted && !quiet) setState(() => _error = 'Không tải được dữ liệu giám sát xe');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FleetOverviewVehicle> get _rows {
    final ql = _q.trim().toLowerCase();
    return (_data?.vehicles ?? []).where((v) {
      if (ql.isNotEmpty && !'${v.naName ?? ''} ${v.code} ${v.plate}'.toLowerCase().contains(ql)) return false;
      if (_only == 'alert') return v.fuelAlerts + v.concreteAlerts > 0;
      if (_only == 'can') return v.hasCan;
      return true;
    }).toList();
  }

  void _select(FleetOverviewVehicle v) {
    setState(() => _selected = v.fleetVehicleId);
    if (v.lat != null && v.lon != null) {
      try {
        _map.move(LatLng(v.lat!, v.lon!), 15);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = _data?.totals;
    if (_data == null && _loading) return const Center(child: CircularProgressIndicator.adaptive());
    if (_data == null && _error != null) {
      return ListView(children: [
        FleetEmpty(_error!, icon: Icons.cloud_off_rounded),
        Center(child: FilledButton.tonal(onPressed: _load, child: const Text('Thử lại'))),
      ]);
    }
    final rows = _rows;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(12.w),
        children: [
          KpiGrid(children: [
            KpiTile(icon: Icons.local_shipping_outlined, label: 'Xe đang giám sát', value: '${t?.vehicles ?? '…'}', color: const Color(0xFF2563EB)),
            KpiTile(icon: Icons.sensors_rounded, label: 'Xe có dữ liệu CAN', value: '${t?.withCan ?? '…'}', color: const Color(0xFF059669)),
            KpiTile(icon: Icons.warning_amber_rounded, label: 'Tụt dầu chưa xử lý (7 ngày)', value: '${t?.fuelAlerts ?? '…'}', color: const Color(0xFFDC2626)),
            KpiTile(icon: Icons.inventory_2_outlined, label: 'Bê tông cần kiểm tra hôm nay', value: '${t?.concreteAlerts ?? '…'}', color: const Color(0xFFD97706)),
            KpiTile(icon: Icons.local_gas_station_outlined, label: 'Xe chưa nhập dung tích bình', value: '${t?.noTankSize ?? '…'}', color: const Color(0xFF64748B)),
          ]),
          FleetSection(
            title: 'Vị trí xe',
            padding: EdgeInsets.all(8.w),
            child: SizedBox(height: 260.h, child: _buildMap()),
          ),
          FleetSection(
            title: 'Cảnh báo cần xử lý (${_data?.alerts.length ?? 0})',
            child: _buildAlerts(),
          ),
          FleetSection(
            title: 'Danh sách xe (${rows.length})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm xe, biển số…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onChanged: (v) => setState(() => _q = v),
                ),
                SizedBox(height: 8.h),
                SegmentChips<String>(
                  options: const [('all', 'Tất cả'), ('alert', 'Có cảnh báo'), ('can', 'Có CAN')],
                  value: _only,
                  onChanged: (v) => setState(() => _only = v),
                ),
                SizedBox(height: 8.h),
                if (rows.isEmpty) const FleetEmpty('Không có xe'),
                for (final v in rows) _vehicleCard(v),
              ],
            ),
          ),
          Center(
            child: Text('Tự cập nhật mỗi 30 giây', style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.outline)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final pts = (_data?.vehicles ?? []).where((v) => v.lat != null && v.lon != null).toList();
    if (pts.isEmpty) return const FleetEmpty('Chưa có vị trí xe', icon: Icons.map_outlined);
    final bounds = LatLngBounds.fromPoints(pts.map((v) => LatLng(v.lat!, v.lon!)).toList());
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.r),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCameraFit: pts.length > 1
              ? CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(30), maxZoom: 15)
              : null,
          initialCenter: LatLng(pts.first.lat!, pts.first.lon!),
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
            userAgentPackageName: 'com.nguyenanh.nagapp',
          ),
          MarkerLayer(
            markers: [
              for (final v in pts)
                Marker(
                  point: LatLng(v.lat!, v.lon!),
                  width: 90,
                  height: 44,
                  child: GestureDetector(
                    onTap: () => _select(v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: v.fleetVehicleId == _selected ? const Color(0xFF2563EB) : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                          ),
                          child: Text(
                            v.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: v.fleetVehicleId == _selected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Icon(
                          v.fuelAlerts + v.concreteAlerts > 0 ? Icons.error_rounded : Icons.circle,
                          size: v.fuelAlerts + v.concreteAlerts > 0 ? 20 : 14,
                          color: v.fuelAlerts + v.concreteAlerts > 0 ? const Color(0xFFDC2626) : activityOf(v.activity).color,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    final alerts = _data?.alerts ?? [];
    if (alerts.isEmpty) return const FleetEmpty('Không có cảnh báo', icon: Icons.check_circle_outline_rounded);
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 360.h),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: alerts.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
        itemBuilder: (_, i) {
          final a = alerts[i];
          final fuel = a.category == 'fuel';
          final c = fuel ? const Color(0xFFDC2626) : const Color(0xFFD97706);
          final tone = a.riskLevel != null ? riskOf(a.riskLevel!) : severityOf(a.severity);
          final head = a.riskLevel != null ? '${riskOf(a.riskLevel!).label} — ${a.riskReason ?? a.title}' : a.title;
          var sub = fmtTime(a.startedAt, withDate: true);
          if (fuel && a.deltaPct != null) {
            sub += ' · tụt ${fmtNum(a.deltaPct, 1)}%${a.dropL != null ? ' ≈ ${fmtNum(a.dropL, 0)} L' : ''}';
          }
          if (!fuel) sub += ' · ${fmtDur(a.durationS)}${a.discharge == true ? ' · vòng tua cao' : ''}';
          return InkWell(
            onTap: () => showFleetEventSheet(
              context,
              eventId: a.id,
              category: a.category,
              cameraAllowed: widget.perms.concreteReview,
              onChanged: () => _load(quiet: true),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8.r)),
                    child: Icon(fuel ? Icons.local_gas_station_rounded : Icons.inventory_2_rounded, size: 16.sp, color: c),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.vehicleCode} · $head',
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2.h),
                        Text(sub, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  ToneChip(label: tone.label, color: tone.color, dense: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _vehicleCard(FleetOverviewVehicle v) {
    final cs = Theme.of(context).colorScheme;
    final act = activityOf(v.activity);
    final sel = v.fleetVehicleId == _selected;
    final lvl = v.fuelLevelPct;
    return GestureDetector(
      onTap: () => _select(v),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: sel ? cs.primary.withValues(alpha: 0.06) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: sel ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.displayName, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
                      Text('${v.plate} · ${v.type ?? ''}', style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                ToneChip(label: act.label, color: act.color, dense: true),
              ],
            ),
            if (v.address != null && v.address!.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text(v.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
            ],
            SizedBox(height: 8.h),
            if (lvl == null)
              Text(v.hasCan ? 'Mức dầu: chưa có dữ liệu mới' : 'Mức dầu: chưa lắp CAN', style: TextStyle(fontSize: 11.sp, color: cs.outline))
            else
              Row(
                children: [
                  Icon(Icons.local_gas_station_outlined, size: 14.sp, color: cs.onSurfaceVariant),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: (lvl / 100).clamp(0, 1).toDouble(),
                        minHeight: 6.h,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: lvl < 20 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text('${lvl.round()}%', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800)),
                ],
              ),
            if (lvl != null)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: v.fuelLevelL != null
                    ? Text('≈ ${fmtNum(v.fuelLevelL, 0)} / ${fmtNum(v.tankCapacityL, 0)} L',
                        style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant))
                    : Text('Chưa nhập dung tích bình', style: TextStyle(fontSize: 11.sp, color: const Color(0xFFD97706))),
              ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (v.trip != null)
                  ToneChip(
                    label: 'Chuyến #${v.trip!.orderNumber ?? '—'} · ${v.trip!.purpose == 'no_load' ? 'Không lấy hàng' : 'Giao hàng'} · từ ${fmtTime(v.trip!.startedAt)}',
                    color: v.trip!.purpose == 'no_load' ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                    dense: true,
                  ),
                ToneChip(
                  label: 'Cảnh báo dầu: ${v.fuelAlerts}',
                  color: v.fuelAlerts > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                  dense: true,
                ),
                ToneChip(
                  label: v.concreteEnabled ? 'Bê tông: ${v.concreteAlerts}' : 'Bê tông: không áp dụng',
                  color: v.concreteAlerts > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                  dense: true,
                ),
              ],
            ),
            if ((widget.perms.fuel && widget.onOpenFuel != null) ||
                (widget.perms.concrete && v.concreteEnabled && widget.onOpenConcrete != null)) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  if (widget.perms.fuel && widget.onOpenFuel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onOpenFuel!(v.fleetVehicleId),
                        icon: const Icon(Icons.local_gas_station_outlined, size: 16),
                        label: const Text('Dầu'),
                      ),
                    ),
                  if (widget.perms.fuel && widget.perms.concrete && v.concreteEnabled) SizedBox(width: 8.w),
                  if (widget.perms.concrete && v.concreteEnabled && widget.onOpenConcrete != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onOpenConcrete!(v.fleetVehicleId),
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Bê tông'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
