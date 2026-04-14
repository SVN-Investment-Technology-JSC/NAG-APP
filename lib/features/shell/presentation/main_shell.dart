import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:vehicle_management/core/network/api_client.dart';
import 'package:vehicle_management/core/network/device_socket_service.dart';
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
  final DeviceSocketService _deviceSocketService = DeviceSocketService();
  final VtrackingService _vtrackingService = VtrackingService();
  final VehicleService _vehicleService = VehicleService(ApiClient.dio);
  Timer? _vtrackingTimer;

  List<OrderModel> _allTodayOrders = [];
  List<OrderModel> _activeOrders = [];
  List<Station> _stations = [];
  List<VtrackingVehicle> _vtrackingVehicles = [];
  List<VehicleModel> _vehicles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _socketService.connect(
      onUpdate: _onSocketUpdate,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    _deviceSocketService.connect(
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    _vtrackingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshVtracking(),
    );
  }

  @override
  void dispose() {
    _vtrackingTimer?.cancel();
    _socketService.dispose();
    _deviceSocketService.dispose();
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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final results = await Future.wait([
        _orderService.getOrdersByDate(today),
        _stationService.getStations(),
        _vtrackingService.fetchVehicles(),
        _vehicleService.getVehicles(),
      ]);

      if (!mounted) return;

      final allVehicles = results[3] as List<VehicleModel>;
      final mixerVehicles =
          allVehicles.where((v) => v.vehicleName.startsWith('X')).toList();
      final mixerVehicleIds =
          mixerVehicles.map((v) => v.vehicleId).toSet();

      final allOrders = results[0] as List<OrderModel>;
      final mixerOrders = allOrders
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList();

      final activeOrders = mixerOrders
          .where((o) => o.orderStatus == 'pending')
          .toList();

      activeOrders
          .sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      final allVtracking = results[2] as List<VtrackingVehicle>;
      final mixerVtracking =
          allVtracking.where((v) => v.vehicleName.startsWith('X')).toList();

      setState(() {
        _allTodayOrders = mixerOrders;
        _activeOrders = activeOrders;
        _stations = results[1] as List<Station>;
        _vtrackingVehicles = mixerVtracking;
        _vehicles = mixerVehicles;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
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
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomePage(
            orders: _activeOrders,
            allTodayOrders: _allTodayOrders,
            stations: _stations,
            vtrackingVehicles: _vtrackingVehicles,
            vehicles: _vehicles,
            socketService: _socketService,
            deviceSocketService: _deviceSocketService,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 64.h,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined,
                color: colorScheme.onSurfaceVariant),
            selectedIcon:
                Icon(Icons.dashboard_rounded, color: colorScheme.primary),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined,
                color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.local_shipping_rounded,
                color: colorScheme.primary),
            label: l10n.vehicleManagement,
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined,
                color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.people_alt_rounded,
                color: colorScheme.primary),
            label: l10n.attendance,
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined,
                color: colorScheme.onSurfaceVariant),
            selectedIcon: Icon(Icons.restaurant_rounded,
                color: colorScheme.primary),
            label: l10n.mealCheck,
          ),
        ],
      ),
    );
  }
}
