import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/network/socket_service.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_monitoring_entry.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/camera_dialog_v2.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/end_of_day_modal_v2.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_map_section.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/queue_history_modal_v2.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/sync_slots_modal_v2.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fleet_alert_bell.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/v2/parking_idle_engine_dashboard_page_v2.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// Home tab (v2). Same constructor, permissions, menu actions and "ready vehicles" computation as [HomePage];
/// only the presentation is new. The original stays in home_page.dart.
class HomePageV2 extends StatefulWidget {
  final List<OrderModel> orders;
  final List<OrderModel> pendingOrders;
  final List<OrderModel> collectingOrders;
  final List<Station> stations;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<VehicleModel> vehicles;
  final VehicleService vehicleService;
  final SocketService socketService;
  final NotificationSocketService notificationService;
  final OrderService orderService;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  const HomePageV2({
    super.key,
    required this.orders,
    required this.pendingOrders,
    required this.collectingOrders,
    required this.stations,
    required this.vtrackingVehicles,
    required this.vehicles,
    required this.vehicleService,
    required this.socketService,
    required this.notificationService,
    required this.orderService,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  State<HomePageV2> createState() => _HomePageV2State();
}

class _HomePageV2State extends State<HomePageV2> {
  final UserManageService _userManageService = UserManageService();
  String _userFullName = '';
  String _userRole = '';
  bool _showYardEntryTime = true;
  final ScrollController _yardScrollController = ScrollController();

  bool _canCheckLog = false;
  bool _canViewMap = false;
  bool _canSyncSlots = false;
  bool _canHistory = false;
  bool _canViewIdleEngine = false;
  bool _canViewReadyVehicles = false;
  FleetPermissions _fleetPerms = const FleetPermissions();

  // ── Logic (identical to HomePage) ─────────────────────────────────────────

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000;
    double toRad(double deg) => deg * pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = (sin(dLat / 2) * sin(dLat / 2)) + cos(toRad(lat1)) * cos(toRad(lat2)) * (sin(dLon / 2) * sin(dLon / 2));
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  void dispose() {
    _yardScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userFullName = prefs.getString('user_full_name') ?? '';
      _userRole = prefs.getString('user_role') ?? '';
    });

    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canCheckLog = _userRole == 'admin' || myPerms.contains('/dashboard__checklog');
          _canViewMap = _userRole == 'admin' || myPerms.contains('/dashboard__view_map');
          _canSyncSlots = _userRole == 'admin' || myPerms.contains('/dashboard__sync_slots');
          _canHistory = _userRole == 'admin' || myPerms.contains('/dashboard__history');
          // same rule as the web's hasPageAccess: the page key or its "__view" action
          _canViewIdleEngine = _userRole == 'admin' || myPerms.contains('/parking-idle-engine') || myPerms.contains('/parking-idle-engine__view');
          _canViewReadyVehicles = _userRole == 'admin' || myPerms.contains('/dashboard__view_yard_vehicles');
          _fleetPerms = FleetPermissions.fromList(_userRole, myPerms);
        });
      }
    } catch (_) {}
  }

  List<Station> get _workingStations => widget.stations.where((s) => s.stationTypeId == 1).toList();

  List<OrderModel> _collectingAtStation(int stationId) =>
      widget.collectingOrders.where((o) => o.stations?.stationId == stationId).toList();

  List<Map<String, dynamic>> get _readyVehicles {
    var geofenceStation = widget.stations.where((s) => s.stationGpsLatitude != null && s.stationGpsLongitude != null).firstOrNull;
    geofenceStation ??= widget.stations.firstOrNull;
    if (geofenceStation == null) return [];
    final station = geofenceStation;
    final stationLatLng = LatLng(station.getLat!, station.getLng!);

    final readyList = widget.vtrackingVehicles.where((v) {
      if (!v.hasPosition) return false;
      if (!v.vehicleName.toUpperCase().startsWith('X')) return false;
      final distance = _haversineDistance(stationLatLng.latitude, stationLatLng.longitude, v.latitude, v.longitude);
      return distance <= station.stationGpsGeofencing;
    }).map((v) {
      final distance = _haversineDistance(stationLatLng.latitude, stationLatLng.longitude, v.latitude, v.longitude);
      final match = widget.orders.where((o) {
        final plate = o.vehicles?.vehicleLicensePlate.toUpperCase() ?? '';
        final vName = v.vehicleName.toUpperCase();
        final vPlate = v.licensePlate.toUpperCase();
        return plate == vName || plate == vPlate;
      }).toList();
      if (match.isNotEmpty) {
        match.sort((a, b) => a.orderInitDatetime.compareTo(b.orderInitDatetime));
      }
      final order = match.isNotEmpty ? match.first : null;
      return {'vehicle': v, 'distance': distance, 'order': order};
    }).toList();

    readyList.sort((a, b) {
      final orderA = a['order'] as OrderModel?;
      final orderB = b['order'] as OrderModel?;
      if (orderA != null && orderB != null) return orderA.orderInitDatetime.compareTo(orderB.orderInitDatetime);
      if (orderA != null) return -1;
      if (orderB != null) return 1;
      final distA = a['distance'] as num;
      final distB = b['distance'] as num;
      if (distA != distB) return distA.compareTo(distB);
      return (a['vehicle'] as VtrackingVehicle).licensePlate.compareTo((b['vehicle'] as VtrackingVehicle).licensePlate);
    });
    return readyList;
  }

  void _onMenu(String value) {
    if (value == 'queue_history') {
      showDialog(context: context, builder: (context) => const QueueHistoryModalV2());
    } else if (value == 'sync_slots') {
      final activeFlowOrders = widget.pendingOrders.where((o) {
        final vStatus = o.vehicles?.vehicleStatus.toLowerCase();
        return vStatus != 'maintenance' && vStatus != 'incident' && vStatus != 'other';
      }).toList();
      showDialog(
        context: context,
        builder: (context) => SyncSlotsModalV2(
          orderService: widget.orderService,
          activeFlowOrders: activeFlowOrders,
          onRefresh: widget.onRefresh,
        ),
      );
    } else if (value == 'parking_idle_engine') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParkingIdleEngineDashboardPageV2()));
    } else if (value == 'fleet_monitoring') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => FleetMonitoringEntry(perms: _fleetPerms)));
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final hour = now.hour;
    final greet = hour < 11 ? 'Chào buổi sáng' : (hour < 14 ? 'Chào buổi trưa' : (hour < 18 ? 'Chào buổi chiều' : 'Chào buổi tối'));
    final firstName = _userFullName.trim().isEmpty ? '' : _userFullName.trim().split(RegExp(r'\s+')).last;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 64.h,
        titleSpacing: 16.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firstName.isEmpty ? greet : '$greet, $firstName',
              style: t.h1.copyWith(fontSize: 19.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(_dateLine(now), style: t.small),
          ],
        ),
        actions: [
          if (_canCheckLog)
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: _ActionChip(
                icon: Icons.fact_check_outlined,
                label: _sentence(l10n.checkLog),
                onTap: () => showDialog(context: context, builder: (context) => EndOfDayModalV2(vehicleService: widget.vehicleService)),
              ),
            ),
          // fleet-monitoring alerts (old general notifications are not shown in the new UI)
          if (_fleetPerms.any) FleetAlertBell(perms: _fleetPerms),
          if (_canSyncSlots || _canHistory || _canViewIdleEngine || _fleetPerms.any)
            PopupMenuButton<String>(
              icon: Icon(Icons.grid_view_rounded, color: t.text),
              tooltip: 'Chức năng',
              offset: Offset(0, 44.h),
              onSelected: _onMenu,
              itemBuilder: (context) => [
                if (_canSyncSlots) _menuItem(t, 'sync_slots', Icons.sync_rounded, l10n.syncSlots, FxTokens.blue),
                if (_canHistory) _menuItem(t, 'queue_history', Icons.history_rounded, l10n.queueHistory, FxTokens.violet),
                if (_canViewIdleEngine) _menuItem(t, 'parking_idle_engine', Icons.power_settings_new_rounded, 'Giám sát nổ máy', FxTokens.amber),
                if (_fleetPerms.any) _menuItem(t, 'fleet_monitoring', Icons.local_shipping_rounded, 'Giám sát xe', FxTokens.emerald),
              ],
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: widget.isLoading
            ? const FxLoadingView(key: ValueKey('loading'))
            : widget.error != null
                ? Center(
                    key: const ValueKey('error'),
                    child: FxEmpty(
                      icon: Icons.cloud_off_rounded,
                      title: l10n.loginGenericError,
                      message: 'Kiểm tra kết nối mạng rồi thử lại.',
                      action: FilledButton.icon(
                        onPressed: widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(l10n.confirm),
                      ),
                    ),
                  )
                : RefreshIndicator.adaptive(
                    key: const ValueKey('data'),
                    onRefresh: widget.onRefresh,
                    child: _content(t, l10n),
                  ),
      ),
    );
  }

  String _dateLine(DateTime d) {
    const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${days[d.weekday - 1]}, ${DateFormat('dd/MM/yyyy').format(d)}';
  }

  PopupMenuItem<String> _menuItem(FxTokens t, String value, IconData icon, String label, Color tone) => PopupMenuItem<String>(
        value: value,
        child: Row(children: [
          FxIconBadge(icon: icon, tone: tone, size: 30),
          SizedBox(width: 12.w),
          Text(label.toUpperCase(), style: t.h3), // all items upper case, like the l10n ones
        ]),
      );

  Widget _content(FxTokens t, AppLocalizations l10n) {
    final stations = _workingStations;
    final ready = _canViewReadyVehicles ? _readyVehicles : const <Map<String, dynamic>>[];
    final online = stations.where((s) => widget.socketService.cameraStatusMap[s.stationId.toString()] == 'connected').length;

    Widget pad(Widget w) => Padding(padding: EdgeInsets.symmetric(horizontal: 16.w), child: w);
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 4.h, 0, 28.h),
      children: [
        pad(_summary(t, l10n, stations.length, online, ready.length)),
        if (stations.isNotEmpty) pad(_stationsCard(t, l10n, stations)),
        if (_canViewMap)
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Theme(
              // the original map section paints itself with surfaceContainerLow: make it a v2 card
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(surfaceContainerLow: t.card),
              ),
              child: HomeMapSection(
                stations: widget.stations,
                vtrackingVehicles: widget.vtrackingVehicles,
                collectingOrders: widget.collectingOrders,
              ),
            ),
          ),
        if (_canViewReadyVehicles && ready.isNotEmpty) pad(_readyCard(t, l10n, ready)),
      ],
    );
  }

  /// "XE TRONG BÃI" -> "Xe trong bãi" (some l10n strings are upper case).
  String _sentence(String s) {
    if (s.isEmpty || s != s.toUpperCase()) return s;
    final l = s.toLowerCase();
    return l[0].toUpperCase() + l.substring(1);
  }

  Widget _summary(FxTokens t, AppLocalizations l10n, int stations, int online, int ready) {
    final collecting = widget.collectingOrders.length;
    Widget stat(IconData icon, String label, String value, String? sub) => Expanded(
          child: Container(
            padding: EdgeInsets.all(11.w),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14.r)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(value, style: t.num(22.sp, color: Colors.white)),
                  const Spacer(),
                  Icon(icon, size: 16.sp, color: Colors.white.withValues(alpha: 0.75)),
                ]),
                SizedBox(height: 4.h),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600, height: 1.2)),
                if (sub != null) ...[
                  SizedBox(height: 2.h),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5.sp, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ],
            ),
          ),
        );

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)]),
        boxShadow: [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_rounded, size: 16.sp, color: Colors.white),
            SizedBox(width: 6.w),
            Text('Tình hình hôm nay', style: TextStyle(fontSize: 13.sp, color: Colors.white, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.socketService.isConnected ? const Color(0xFF4ADE80) : const Color(0xFFFCA5A5),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 5.w),
                Text(widget.socketService.isConnected ? 'Trực tuyến' : 'Mất kết nối',
                    style: TextStyle(fontSize: 10.sp, color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          SizedBox(height: 12.h),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            stat(Icons.factory_rounded, 'Trạm hoạt động', '$stations', stations > 0 ? '$online/$stations camera' : null),
            SizedBox(width: 8.w),
            stat(Icons.local_shipping_rounded, 'Xe ${l10n.collecting.toLowerCase()}', '$collecting', null),
            if (_canViewReadyVehicles) ...[
              SizedBox(width: 8.w),
              stat(Icons.local_parking_rounded, _sentence(l10n.parkedVehicles), '$ready', null),
            ],
          ])),
        ],
      ),
    );
  }

  Widget _stationsCard(FxTokens t, AppLocalizations l10n, List<Station> stations) {
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.factory_rounded,
            title: l10n.activeStations,
            subtitle: 'Trạng thái camera và xe đang lấy hàng tại trạm',
            tone: FxTokens.blue,
            trailing: FxPill(label: '${stations.length}', tone: FxTokens.blue),
          ),
          for (var i = 0; i < stations.length; i++) ...[
            if (i > 0) Divider(height: 20.h, color: t.divider),
            _stationRow(t, l10n, stations[i]),
          ],
        ],
      ),
    );
  }

  Widget _stationRow(FxTokens t, AppLocalizations l10n, Station station) {
    final collecting = _collectingAtStation(station.stationId);
    final connected = widget.socketService.cameraStatusMap[station.stationId.toString()] == 'connected';
    final camTone = connected ? FxTokens.emerald : FxTokens.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(station.stationName, style: t.h3.copyWith(fontSize: 14.5.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 2.h),
                  Text(
                    collecting.isEmpty ? 'Không có xe đang lấy hàng' : '${collecting.length} xe ${l10n.collecting.toLowerCase()}',
                    style: t.tiny.copyWith(color: collecting.isEmpty ? t.textMuted : t.ink(FxTokens.emerald), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Material(
              color: t.soft(camTone),
              borderRadius: BorderRadius.circular(10.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(10.r),
                onTap: () => CameraDialogV2.show(context, station),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(connected ? Icons.videocam_rounded : Icons.videocam_off_rounded, size: 15.sp, color: t.ink(camTone)),
                    SizedBox(width: 5.w),
                    Text(
                      connected ? l10n.cameraConnected : l10n.cameraDisconnected,
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: t.ink(camTone)),
                    ),
                  ]),
                ),
              ),
            ),
          ],
        ),
        if (collecting.isNotEmpty) ...[
          SizedBox(height: 10.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              for (final o in collecting)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: t.soft(FxTokens.emerald),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: FxTokens.emerald.withValues(alpha: 0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_shipping_rounded, size: 14.sp, color: t.ink(FxTokens.emerald)),
                    SizedBox(width: 6.w),
                    Text(o.vehicles?.vehicleLicensePlate ?? '---',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800, color: t.text, fontFeatures: FxTokens.tabular)),
                  ]),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _readyCard(FxTokens t, AppLocalizations l10n, List<Map<String, dynamic>> ready) {
    return FxCard(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.local_parking_rounded,
            title: _sentence(l10n.parkedVehicles),
            subtitle: 'Thứ tự theo giờ vào bãi, sau đó theo khoảng cách',
            tone: FxTokens.violet,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: _showYardEntryTime ? 'Ẩn giờ vào bãi' : 'Hiện giờ vào bãi',
                visualDensity: VisualDensity.compact,
                icon: Icon(_showYardEntryTime ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18.sp, color: t.textMuted),
                onPressed: () => setState(() => _showYardEntryTime = !_showYardEntryTime),
              ),
              FxPill(label: '${ready.length} xe', tone: FxTokens.violet),
            ]),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 400.h),
            child: Scrollbar(
              controller: _yardScrollController,
              thumbVisibility: ready.length > 6,
              child: ListView.builder(
                controller: _yardScrollController,
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: 6.h),
                itemCount: ready.length,
                itemBuilder: (_, i) => _readyRow(t, i, ready[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readyRow(FxTokens t, int index, Map<String, dynamic> item) {
    final v = item['vehicle'] as VtrackingVehicle;
    final distance = item['distance'] as num;
    final order = item['order'] as OrderModel?;
    String timeStr = '--:--:--';
    String dateStr = '--/--/----';
    if (order != null && order.orderInitDatetime.isNotEmpty) {
      try {
        final dt = DateTime.parse(order.orderInitDatetime).toLocal();
        timeStr = DateFormat('HH:mm:ss').format(dt);
        dateStr = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }
    final first = index == 0 && order != null;
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: first ? t.soft(FxTokens.violet) : t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: first ? FxTokens.violet.withValues(alpha: 0.35) : t.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: first ? FxTokens.violet : t.card, shape: BoxShape.circle, border: Border.all(color: first ? FxTokens.violet : t.border)),
            child: Text('${index + 1}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: first ? Colors.white : t.textMuted, fontFeatures: FxTokens.tabular)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.licensePlate, style: t.h3.copyWith(fontFeatures: FxTokens.tabular), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (v.vehicleName.isNotEmpty) Text(v.vehicleName, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.near_me_outlined, size: 12.sp, color: t.textFaint),
                SizedBox(width: 3.w),
                Text(distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.round()} m',
                    style: t.tiny.copyWith(color: t.text, fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular)),
              ]),
              if (order != null && _showYardEntryTime) ...[
                SizedBox(height: 2.h),
                Text('$timeStr · $dateStr', style: t.tiny.copyWith(fontSize: 9.5.sp, fontFeatures: FxTokens.tabular)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: t.soft(FxTokens.blue),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15.sp, color: t.ink(FxTokens.blue)),
            SizedBox(width: 5.w),
            Text(label, style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w800, color: t.ink(FxTokens.blue))),
          ]),
        ),
      ),
    );
  }
}
