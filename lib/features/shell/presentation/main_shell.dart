import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/auth_interceptor.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/network/socket_service.dart';
import 'package:nguyenanh/features/attendance/presentation/attendance_page.dart';
import 'package:nguyenanh/features/home/presentation/home_page.dart';
import 'package:nguyenanh/features/meal/presentation/meal_check_page.dart';
import 'package:nguyenanh/features/profile/presentation/profile_page.dart';
import 'package:nguyenanh/features/reports/presentation/pages/report_page.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/stations/data/services/station_service.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vehicle/presentation/vehicle_management_page.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/features/vtracking/data/services/vtracking_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/features/chatbot/presentation/widgets/chatbot_bubble.dart';

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
  List<OrderModel> _yardOrders = [];
  List<Station> _stations = [];
  List<VtrackingVehicle> _vtrackingVehicles = [];
  List<VehicleModel> _vehicles = [];
  List<VtrackingVehicle> _allVtrackingVehicles = [];
  List<VehicleModel> _allVehicles = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _targetTripDate;

  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canViewReports = false;
  bool _canAIAssistant = false;
  bool _canViewTripsTab = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _setupTokenRefreshListener();
    _loadData();
    _connectSocket();
    _notificationService.connect();
    _vtrackingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshVtracking(),
    );
  }

  Future<void> _loadPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('user_role') ?? '';
    debugPrint('[MainShell] _loadPermissions userRole: $_userRole');
    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      debugPrint('[MainShell] Loaded permissions for $_userRole: $myPerms');
      if (mounted) {
        setState(() {
          _canViewReports = _userRole == 'admin' || myPerms.contains('/reports/production');
          _canAIAssistant = _userRole == 'admin' || myPerms.contains('/ai-assistant');
          _canViewTripsTab = _userRole == 'admin' ||
              myPerms.contains('/dashboard__view_lot_order') ||
              myPerms.contains('/dashboard__view_lot_order_limit_3');
        });
        debugPrint('[MainShell] _canViewTripsTab = $_canViewTripsTab');
      }
    } catch (e, stack) {
      debugPrint('[MainShell] Failed to load permissions: $e\n$stack');
    }
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
        _allVtrackingVehicles = vehicles;
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
        _orderService.getOrders(statuses: ['transporting']).catchError((e) {
          debugPrint('[LOAD] Transporting orders failed: $e');
          return <OrderModel>[];
        }),
        _orderService.getTodayOrders().catchError((e) {
          debugPrint('[LOAD] Today orders failed: $e');
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

      final allVehicles = results[6] as List<VehicleModel>;
      final activeVehicles =
          allVehicles.where((v) => v.vehicleStatus != 'maintenance').toList();
      final mixerVehicles =
          activeVehicles.where((v) => v.vehicleName.startsWith('X')).toList();
      final mixerVehicleIds =
          mixerVehicles.map((v) => v.vehicleId).toSet();

      final pendingOrders = (results[0] as List<OrderModel>).where((o) {
        if (o.vehicles == null) return false;
        if (!mixerVehicleIds.contains(o.vehicles!.vehicleId)) return false;
        
        final vStatus = o.vehicles!.vehicleStatus.toLowerCase();
        final isShiftClosed = o.shiftClosing?.shiftStatus == 1;
        return !isShiftClosed && vStatus != 'maintenance' && vStatus != 'incident' && vStatus != 'other';
      }).toList();

      final collectingOrders = (results[1] as List<OrderModel>)
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList();

      final transportingOrders = (results[2] as List<OrderModel>)
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList();

      final todayOrders = (results[3] as List<OrderModel>)
          .where((o) =>
              o.vehicles != null &&
              mixerVehicleIds.contains(o.vehicles!.vehicleId))
          .toList();

      // Combine all orders for the yard list to find the correct init_datetime
      // (only active statuses, exclude today's completed orders to avoid incorrect timestamps)
      final allActiveOrders = [
        ...pendingOrders, 
        ...collectingOrders, 
        ...transportingOrders,
      ];
      // Sort and remove duplicates based on orderId
      final Map<int, OrderModel> uniqueOrders = {};
      for (var o in allActiveOrders) {
        uniqueOrders[o.orderId] = o;
      }
      final finalOrders = uniqueOrders.values.toList()
        ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

      final allVtracking = results[5] as List<VtrackingVehicle>;
      final mixerVtracking =
          allVtracking.where((v) => v.vehicleName.startsWith('X')).toList();

      setState(() {
        _pendingOrders = pendingOrders; 
        _collectingOrders = collectingOrders;
        _yardOrders = finalOrders;
        _stations = results[4] as List<Station>;
        _vtrackingVehicles = mixerVtracking;
        _vehicles = mixerVehicles;
        _allVtrackingVehicles = allVtracking;
        _allVehicles = activeVehicles;
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final shell = Builder(
      builder: (context) {
        final children = <Widget>[];
        final destinations = <NavigationDestination>[];

        // 1. Home
        children.add(HomePage(
          orders: _yardOrders,
          pendingOrders: _pendingOrders,
          collectingOrders: _collectingOrders,
          stations: _stations,
          vtrackingVehicles: _vtrackingVehicles,
          vehicles: _vehicles,
          vehicleService: _vehicleService,
          socketService: _socketService,
          notificationService: _notificationService,
          orderService: _orderService,
          isLoading: _isLoading,
          error: _error,
          onRefresh: _loadData,
        ));
        destinations.add(NavigationDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard_rounded),
          label: l10n.homeTab,
        ));

        // 2. Trips
        int tripsTabIndex = -1;
        if (_canViewTripsTab) {
          tripsTabIndex = children.length;
          children.add(VehicleManagementPage(
            pendingOrders: _pendingOrders,
            vehicles: _allVehicles,
            vtrackingVehicles: _allVtrackingVehicles,
            stations: _stations,
            initialDate: _targetTripDate,
            onRefresh: _loadData,
            notificationService: _notificationService,
          ));
          destinations.add(NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping_rounded),
            label: l10n.tripsTab,
          ));
        }

        // 3. Reports
        if (_canViewReports) {
          children.add(ReportPage(
            onNavigateTrips: (date) {
              if (tripsTabIndex != -1) {
                setState(() {
                  _targetTripDate = date;
                  _currentIndex = tripsTabIndex;
                });
              }
            },
          ));
          destinations.add(NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: l10n.reportsTab,
          ));
        }

        // 4. Profile
        children.add(ProfilePage(
          onNavigateHome: () => setState(() => _currentIndex = 0),
          onNavigateTrips: () {
            if (tripsTabIndex != -1) {
              setState(() => _currentIndex = tripsTabIndex);
            }
          },
          onLogout: () {
            _socketService.dispose();
            _notificationService.dispose();
          },
        ));
        destinations.add(NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(Icons.person_rounded),
          label: l10n.profileTab,
        ));

        final safeIndex = _currentIndex < children.length ? _currentIndex : children.length - 1;
        final cleanIndex = safeIndex < 0 ? 0 : safeIndex;

        return Scaffold(
          key: mainShellScaffoldKey,
          backgroundColor: colorScheme.surface,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.navigationBarTheme.backgroundColor ?? colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: NavigationBar(
                selectedIndex: cleanIndex,
                onDestinationSelected: (i) {
                  setState(() => _currentIndex = i);
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: colorScheme.primary.withOpacity(0.1),
                destinations: destinations,
              ),
            ),
          ),
          body: IndexedStack(
            index: cleanIndex,
            children: children,
          ),
        );
      },
    );

    if (_canAIAssistant) {
      return ChatbotBubble(child: shell);
    }
    return shell;
  }
}
