import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/l10n/language_provider.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/network/socket_service.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/core/theme/theme_toggle_button.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_map_section.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_order_item.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_station_card.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_user_header.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/features/setup/presentation/selection_page.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class HomePage extends StatefulWidget {
  final List<OrderModel> orders;
  final List<OrderModel> collectingOrders;
  final List<Station> stations;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<VehicleModel> vehicles;
  final SocketService socketService;
  final NotificationSocketService notificationService;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;

  const HomePage({
    super.key,
    required this.orders,
    required this.collectingOrders,
    required this.stations,
    required this.vtrackingVehicles,
    required this.vehicles,
    required this.socketService,
    required this.notificationService,
    required this.isLoading,
    this.error,
    required this.onRefresh,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userFullName = '';
  String _userRole = '';

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
    final sorted = List<OrderModel>.from(widget.orders)
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    return sorted;
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
          'Trang chủ',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        automaticallyImplyLeading: false,
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
            SliverToBoxAdapter(
              child: HomeMapSection(
                stations: widget.stations,
                vtrackingVehicles: widget.vtrackingVehicles,
                collectingOrders: _collectingOrders,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 20.h)),
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

  List<Widget> _buildStationSliver() {
    return _workingStations.map((station) {
      final cameraStatus =
          widget.socketService.cameraStatusMap[station.stationId.toString()];
      return SliverToBoxAdapter(
        child: HomeStationCard(
          station: station,
          collectingVehicles: _collectingAtStation(station.stationId),
          isCameraConnected: cameraStatus == 'connected',
        ),
      );
    }).toList();
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
