import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/home/presentation/widgets/end_of_day_modal.dart';
import 'package:nguyenanh/features/home/presentation/widgets/queue_history_modal.dart';
import 'package:nguyenanh/features/home/presentation/widgets/sync_slots_modal.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:intl/intl.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/pages/parking_idle_engine_dashboard_page.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_monitoring_entry.dart';

import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/network/socket_service.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/core/theme/theme_toggle_button.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_map_section.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_order_item.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_station_card.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_user_header.dart';
import 'package:nguyenanh/features/notifications/presentation/widgets/notification_bottom_sheet.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
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

  const HomePage({
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
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000; // Earth radius in meters
    double toRad(double deg) => deg * pi / 180;
    
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
              cos(toRad(lat1)) * cos(toRad(lat2)) * 
              (sin(dLon / 2) * sin(dLon / 2));
    
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

  List<Station> get _workingStations =>
      widget.stations.where((s) => s.stationTypeId == 1).toList();

  List<OrderModel> _collectingAtStation(int stationId) {
    return widget.collectingOrders
        .where((o) => o.stations?.stationId == stationId)
        .toList();
  }

  List<OrderModel> get _collectingOrders => widget.collectingOrders;

  List<OrderModel> get _sortedOrders {
    final sorted = List<OrderModel>.from(widget.pendingOrders)
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    return sorted;
  }

  List<Map<String, dynamic>> get _readyVehicles {
    // 1. Get the geofence station (Prefer explicit GPS fields first, like React find())
    var geofenceStation = widget.stations.where(
      (s) => s.stationGpsLatitude != null && s.stationGpsLongitude != null,
    ).firstOrNull;
    
    // Fallback to the first station if none found with explicit GPS fields
    geofenceStation ??= widget.stations.firstOrNull;
    
    if (geofenceStation == null) return [];
    final station = geofenceStation;
    final stationLatLng = LatLng(station.getLat!, station.getLng!);

    // 2. Filter and compute distances
    final readyList = widget.vtrackingVehicles.where((v) {
      if (!v.hasPosition) return false;
      // In React it filters by name starting with 'X'
      if (!v.vehicleName.toUpperCase().startsWith('X')) return false;

      final distance = _haversineDistance(stationLatLng.latitude, stationLatLng.longitude, v.latitude, v.longitude);
      
      // In range check (using the geofence radius from station model)
      return distance <= station.stationGpsGeofencing;
    }).map((v) {
      final distance = _haversineDistance(stationLatLng.latitude, stationLatLng.longitude, v.latitude, v.longitude);

      // 3. Find matching order for sorting and entry time
      // We look into the pending orders to see when they were initialized
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

      return {
        'vehicle': v,
        'distance': distance,
        'order': order,
      };
    }).toList();

    // 4. Sort the final list
    readyList.sort((a, b) {
      final orderA = a['order'] as OrderModel?;
      final orderB = b['order'] as OrderModel?;

      if (orderA != null && orderB != null) {
        return orderA.orderInitDatetime.compareTo(orderB.orderInitDatetime);
      }
      if (orderA != null) return -1;
      if (orderB != null) return 1;

      // Secondary sort by distance
      final distA = a['distance'] as num;
      final distB = b['distance'] as num;
      if (distA != distB) return distA.compareTo(distB);

      // Tertiary sort by plate
      return (a['vehicle'] as VtrackingVehicle).licensePlate.compareTo((b['vehicle'] as VtrackingVehicle).licensePlate);
    });

    return readyList;
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.home,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: false,
        actions: [
          if (_canCheckLog)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
            child: OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => EndOfDayModal(
                    vehicleService: widget.vehicleService,
                  ),
                );
              },
              icon: Icon(Icons.save_outlined, size: 16.sp),
              label: Text(
                l10n.checkLog,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
                minimumSize: Size(0, 32.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ),
          if (NotificationSocketService.showOnScreen) NotificationBadge(notificationService: widget.notificationService),
          if (_canSyncSlots || _canHistory || _canViewIdleEngine || _fleetPerms.any)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: PopupMenuButton<String>(
              icon: Icon(Icons.menu, color: colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              color: colorScheme.surface,
              elevation: 4,
              onSelected: (value) {
                if (value == 'queue_history') {
                  showDialog(
                    context: context,
                    builder: (context) => const QueueHistoryModal(),
                  );
                } else if (value == 'sync_slots') {
                  final activeFlowOrders = widget.pendingOrders.where((o) {
                    final vStatus = o.vehicles?.vehicleStatus.toLowerCase();
                    return vStatus != 'maintenance' && vStatus != 'incident' && vStatus != 'other';
                  }).toList();
                  showDialog(
                    context: context,
                    builder: (context) => SyncSlotsModal(
                      orderService: widget.orderService,
                      activeFlowOrders: activeFlowOrders,
                      onRefresh: widget.onRefresh,
                    ),
                  );
                } else if (value == 'parking_idle_engine') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ParkingIdleEngineDashboardPage(),
                  ));
                } else if (value == 'fleet_monitoring') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FleetMonitoringEntry(perms: _fleetPerms),
                  ));
                }
              },
              itemBuilder: (BuildContext context) => [
                if (_canSyncSlots)
                  PopupMenuItem<String>(
                    value: 'sync_slots',
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: colorScheme.primary, size: 20.sp),
                      SizedBox(width: 12.w),
                      Text(
                        l10n.syncSlots,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    ),
                  ),
                if (_canHistory)
                  PopupMenuItem<String>(
                    value: 'queue_history',
                  child: Row(
                    children: [
                      Icon(Icons.history, color: colorScheme.primary, size: 20.sp),
                      SizedBox(width: 12.w),
                      Text(
                        l10n.queueHistory,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canViewIdleEngine)
                  PopupMenuItem<String>(
                    value: 'parking_idle_engine',
                    child: Row(
                      children: [
                        Icon(Icons.power_settings_new_rounded, color: colorScheme.primary, size: 20.sp),
                        SizedBox(width: 12.w),
                        Text(
                          'GIÁM SÁT NỔ MÁY',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_fleetPerms.any)
                  PopupMenuItem<String>(
                    value: 'fleet_monitoring',
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, color: colorScheme.primary, size: 20.sp),
                        SizedBox(width: 12.w),
                        Text(
                          'GIÁM SÁT XE',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: _buildBody(theme, colorScheme, l10n),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    Widget content;
    if (widget.isLoading) {
      content = const Center(key: ValueKey('loading'), child: CircularProgressIndicator.adaptive());
    } else if (widget.error != null) {
      content = _ErrorView(key: const ValueKey('error'), l10n: l10n, onRetry: widget.onRefresh);
    } else {
      content = RefreshIndicator.adaptive(
        key: const ValueKey('data'),
        onRefresh: widget.onRefresh,
        child: CustomScrollView(
          slivers: [
            ..._buildStationSliver(),
            if (_canViewMap)
              SliverToBoxAdapter(
                child: HomeMapSection(
                  stations: widget.stations,
                  vtrackingVehicles: widget.vtrackingVehicles,
                  collectingOrders: _collectingOrders,
                ),
              ),
            if (_canViewReadyVehicles)
              ..._buildReadyVehiclesSliver(theme, colorScheme, l10n),
            SliverToBoxAdapter(child: SizedBox(height: 24.h)),
          ],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: content,
    );
  }

  List<Widget> _buildReadyVehiclesSliver(ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final readyList = _readyVehicles;
    if (readyList.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800.w),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xsH),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, size: 18.sp, color: colorScheme.primary),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            l10n.parkedVehicles.toUpperCase(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showYardEntryTime ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            size: 18.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          onPressed: () => setState(() => _showYardEntryTime = !_showYardEntryTime),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: 12.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            '${readyList.length} XE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 380.h),
                    child: Scrollbar(
                      controller: _yardScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _yardScrollController,
                        padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
                        child: Column(
                          children: readyList.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
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

                            return Container(
                              margin: EdgeInsets.only(bottom: index == readyList.length - 1 ? 0 : 6.h),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${v.licensePlate}${v.vehicleName.isNotEmpty ? ' | ${v.vehicleName}' : ''}',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        distance >= 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.round()} m',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                      if (order != null && _showYardEntryTime)
                                        Padding(
                                          padding: EdgeInsets.only(top: 2.h),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                timeStr,
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 9.sp,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                dateStr,
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 9.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
}

  List<Widget> _buildStationSliver() {
    if (_workingStations.isEmpty) return [];

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return [
      SliverToBoxAdapter(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xsH),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
                child: Row(
                  children: [
                    Icon(Icons.business_rounded, size: 18.sp, color: colorScheme.primary),
                    SizedBox(width: 8.w),
                    Text(
                      l10n.activeStations,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              ..._workingStations.asMap().entries.map((entry) {
                final index = entry.key;
                final station = entry.value;
                final cameraStatus = widget.socketService.cameraStatusMap[station.stationId.toString()];
                return Column(
                  children: [
                    if (index > 0)
                      Divider(height: 1, indent: 16.w, endIndent: 16.w, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    HomeStationCard(
                      station: station,
                      collectingVehicles: _collectingAtStation(station.stationId),
                      isCameraConnected: cameraStatus == 'connected',
                    ),
                  ],
                );
              }),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      )
    ];
  }

  Widget _buildOrdersSliver(
      AppLocalizations l10n, ColorScheme colorScheme, ThemeData theme) {
    final sorted = _sortedOrders;

    if (sorted.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 64.sp,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                ),
                SizedBox(height: AppSpacing.mdH),
                Text(
                  l10n.noPendingOrders,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }


    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return HomeOrderItem(
            order: sorted[index],
            orderNumber: index + 1,
            vehicles: widget.vehicles,
          );
        },
        childCount: sorted.length,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.l10n, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        margin: EdgeInsets.all(AppSpacing.lg),
        padding: EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 48.sp, color: colorScheme.error),
            ),
            SizedBox(height: 16.h),
            Text(
              l10n.loginGenericError,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lgH),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.confirm),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  final List<OrderModel> orders;
  const _OrdersHeader({required this.orders});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 12.h, AppSpacing.md, AppSpacing.xsH),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 18.sp, color: colorScheme.primary),
          SizedBox(width: AppSpacing.sm),
          Text(
            l10n.todayOrders,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3.h),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '${orders.length}',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
