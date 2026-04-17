import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vehicle_management/core/network/api_client.dart';
import 'package:vehicle_management/core/network/auth_interceptor.dart';
import 'package:vehicle_management/core/network/notification_socket_service.dart';
import 'package:vehicle_management/core/network/socket_service.dart';
import 'package:vehicle_management/features/attendance/presentation/attendance_page.dart';
import 'package:vehicle_management/features/home/presentation/home_page.dart';
import 'package:vehicle_management/features/meal/presentation/meal_check_page.dart';
import 'package:vehicle_management/features/order/data/models/order_model.dart';
import 'package:vehicle_management/features/order/order_service.dart';
import 'package:vehicle_management/features/stations/data/models/station_model.dart';
import 'package:vehicle_management/features/stations/data/services/station_service.dart';
import 'package:vehicle_management/features/vehicle/data/models/vehicle_model.dart';
import 'package:vehicle_management/features/vehicle/data/services/vehicle_service.dart';
import 'package:vehicle_management/features/vehicle/presentation/vehicle_management_page.dart';
import 'package:vehicle_management/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:vehicle_management/features/vtracking/data/services/vtracking_service.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

/// Global key to open the main shell's side drawer from any page.
final GlobalKey<ScaffoldState> mainShellScaffoldKey =
    GlobalKey<ScaffoldState>();

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final OrderService _orderService = OrderService(ApiClient.dio);
  final StationService _stationService = StationService(ApiClient.dio);
  final SocketService _socketService = SocketService();
  final NotificationSocketService _notificationService = NotificationSocketService();
  final VtrackingService _vtrackingService = VtrackingService();
  final VehicleService _vehicleService = VehicleService(ApiClient.dio);
  Timer? _vtrackingTimer;

  List<OrderModel> _pendingOrders = [];
  List<OrderModel> _collectingOrders = [];
  List<Station> _stations = [];
  List<VtrackingVehicle> _vtrackingVehicles = [];
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupTokenRefreshListener();
    _loadData();
    _connectSocket();
    _notificationService.connect();
    _vtrackingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshVtracking(),
    );
  }

  void _setupTokenRefreshListener() {
    final authInterceptor = ApiClient.dio.interceptors
        .whereType<AuthInterceptor>()
        .firstOrNull;
    authInterceptor?.onTokenRefreshed = _reconnectSocket;
  }

  void _connectSocket() {
    _socketService.connect(
      onUpdate: _onSocketUpdate,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _reconnectSocket() {
    _socketService.dispose();
    _connectSocket();
    _notificationService.connect();
  }

  @override
  void dispose() {
    _vtrackingTimer?.cancel();
    _socketService.dispose();
    _notificationService.dispose();
    super.dispose();
  } 

  void _onSocketUpdate() {
    if (!mounted) return;
    _loadData();
  }

  Future<void> _refreshVtracking() async {
    try {
      final vehicles = await _vtrackingService.fetchVehicles();
      if (!mounted) return;
      setState(() {
        _vtrackingVehicles =
            vehicles.where((v) => v.vehicleName.startsWith('X')).toList();
      });
    } catch (e) {
      debugPrint('[VTRACKING] Refresh error: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    // Reconnect sockets nếu đã mất kết nối
    if (!_socketService.isConnected) {
      _connectSocket();
    }
    if (!_notificationService.isConnected) {
      _notificationService.connect();
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _orderService.getOrders(statuses: ['pending']).catchError((e) {
          debugPrint('[LOAD] Pending orders failed: $e');
          return <OrderModel>[];
        }),
        _orderService.getOrders(statuses: ['collecting']).catchError((e) {
          debugPrint('[LOAD] Collecting orders failed: $e');
          return <OrderModel>[];
        }),
        _stationService.getStations().catchError((e) {
          debugPrint('[LOAD] Stations failed: $e');
          return <Station>[];
        }),
        _vtrackingService.fetchVehicles(),
        _vehicleService.getVehicles().catchError((e) {
          debugPrint('[LOAD] Vehicles failed: $e');
          return <VehicleModel>[];
        }),
      ]);

      if (!mounted) return;

      final allVehicles = results[4] as List<VehicleModel>;
      final mixerVehicles =
          allVehicles.where((v) => v.vehicleName.startsWith('X') && v.vehicleStatus != 'maintenance').toList();
      final mixerVehicleIds =
          mixerVehicles.map((v) => v.vehicleId).toSet();

      final pendingOrders = (results[0] as List<OrderModel>)
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList()
        ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      final collectingOrders = (results[1] as List<OrderModel>)
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList();

      final allVtracking = results[3] as List<VtrackingVehicle>;
      final mixerVtracking =
          allVtracking.where((v) => v.vehicleName.startsWith('X')).toList();

      setState(() {
        _pendingOrders = pendingOrders;
        _collectingOrders = collectingOrders;
        _stations = results[2] as List<Station>;
        _vtrackingVehicles = mixerVtracking;
        _vehicles = mixerVehicles;
        _isLoading = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint('[LOAD] Unexpected error: $e\n$stackTrace');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: mainShellScaffoldKey,
      drawer: NavigationDrawer(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          Navigator.of(context).pop();
        },
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 16.w, 12.h),
            child: Row(
              children: [
                Icon(Icons.apps_rounded,
                    color: colorScheme.primary, size: 22.sp),
                SizedBox(width: 10.w),
                Text(
                  'Menu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          Divider(color: colorScheme.outlineVariant, height: 1),
          SizedBox(height: 8.h),
          NavigationDrawerDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: Text(l10n.home),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping_rounded),
            label: Text(l10n.vehicleManagement),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.people_alt_outlined),
            selectedIcon: const Icon(Icons.people_alt_rounded),
            label: Text(l10n.attendance),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant_rounded),
            label: Text(l10n.mealCheck),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            orders: _pendingOrders,
            collectingOrders: _collectingOrders,
            stations: _stations,
            vtrackingVehicles: _vtrackingVehicles,
            vehicles: _vehicles,
            socketService: _socketService,
            notificationService: _notificationService,
            isLoading: _isLoading,
            error: _error,
            onRefresh: _loadData,
          ),
          VehicleManagementPage(
            vehicles: _vehicles,
            vtrackingVehicles: _vtrackingVehicles,
            stations: _stations,
          ),
          const AttendancePage(),
          const MealCheckPage(),
        ],
      ),
    );
  }
}
