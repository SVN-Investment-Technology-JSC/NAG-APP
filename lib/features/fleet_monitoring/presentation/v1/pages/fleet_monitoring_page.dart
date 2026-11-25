import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/pages/fleet_concrete_tab.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/pages/fleet_fuel_tab.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/pages/fleet_overview_tab.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v1/widgets/fleet_common.dart';

/// "Giám sát xe": Tổng quan / Nhiên liệu / Bê tông thừa. Each tab is shown only with its permission
/// (same permission keys as the web sidebar). "Ngưỡng giám sát" (configuration) stays on the web.
class FleetMonitoringPage extends StatefulWidget {
  /// Permissions already loaded by the caller (skips a second request); loaded here when null.
  final FleetPermissions? perms;

  /// Switch to the new UI (shown in the app bar when set).
  final VoidCallback? onSwitchUi;

  const FleetMonitoringPage({super.key, this.perms, this.onSwitchUi});

  @override
  State<FleetMonitoringPage> createState() => _FleetMonitoringPageState();
}

class _FleetMonitoringPageState extends State<FleetMonitoringPage> with TickerProviderStateMixin {
  FleetPermissions? _perms;
  bool _failed = false;
  TabController? _tabs;
  final _fuelRequest = ValueNotifier<String?>(null);
  final _concreteRequest = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    if (widget.perms != null) {
      _setPerms(widget.perms!);
    } else {
      _loadPerms();
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    _fuelRequest.dispose();
    _concreteRequest.dispose();
    super.dispose();
  }

  Future<void> _loadPerms() async {
    try {
      final p = await FleetPermissions.load();
      if (mounted) setState(() => _setPerms(p));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _setPerms(FleetPermissions p) {
    _perms = p;
    final n = [p.overview, p.fuel, p.concrete].where((x) => x).length;
    _tabs?.dispose();
    _tabs = n > 0 ? TabController(length: n, vsync: this) : null;
  }

  int _indexOf(String key) {
    final p = _perms!;
    final keys = [if (p.overview) 'overview', if (p.fuel) 'fuel', if (p.concrete) 'concrete'];
    return keys.indexOf(key);
  }

  void _openFuel(String vid) {
    final i = _indexOf('fuel');
    if (i < 0) return;
    _fuelRequest.value = vid;
    _tabs?.animateTo(i);
  }

  void _openConcrete(String vid) {
    final i = _indexOf('concrete');
    if (i < 0) return;
    _concreteRequest.value = vid;
    _tabs?.animateTo(i);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _perms;
    final tabs = <Tab>[];
    final views = <Widget>[];
    if (p != null) {
      if (p.overview) {
        tabs.add(const Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: 'Tổng quan'));
        views.add(FleetOverviewTab(
          perms: p,
          onOpenFuel: p.fuel ? _openFuel : null,
          onOpenConcrete: p.concrete ? _openConcrete : null,
        ));
      }
      if (p.fuel) {
        tabs.add(const Tab(icon: Icon(Icons.local_gas_station_outlined, size: 20), text: 'Nhiên liệu'));
        views.add(FleetFuelTab(request: _fuelRequest));
      }
      if (p.concrete) {
        tabs.add(const Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Bê tông thừa'));
        views.add(FleetConcreteTab(perms: p, request: _concreteRequest));
      }
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        title: Text('Giám sát xe', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        actions: [
          if (widget.onSwitchUi != null)
            TextButton.icon(
              onPressed: widget.onSwitchUi,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Giao diện mới'),
            ),
        ],
        bottom: tabs.length > 1 && _tabs != null
            ? TabBar(
                controller: _tabs,
                tabs: tabs,
                labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                unselectedLabelStyle: TextStyle(fontSize: 12.sp),
              )
            : null,
      ),
      body: p == null
          ? (_failed
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const FleetEmpty('Không tải được quyền truy cập', icon: Icons.lock_outline_rounded),
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() => _failed = false);
                        _loadPerms();
                      },
                      child: const Text('Thử lại'),
                    ),
                  ]),
                )
              : const Center(child: CircularProgressIndicator.adaptive()))
          : views.isEmpty
              ? const Center(child: FleetEmpty('Bạn chưa được cấp quyền xem chức năng này', icon: Icons.lock_outline_rounded))
              : views.length == 1
                  ? views.first
                  : TabBarView(controller: _tabs, physics: const NeverScrollableScrollPhysics(), children: views),
    );
  }
}
