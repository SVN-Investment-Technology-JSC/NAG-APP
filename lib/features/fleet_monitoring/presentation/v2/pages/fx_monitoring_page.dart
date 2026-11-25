import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/pages/fx_concrete_tab.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/pages/fx_fuel_tab.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/pages/fx_overview_tab.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';

/// "Giám sát xe" (v2). Same tabs and permission rules as v1.
class FxMonitoringPage extends StatefulWidget {
  final FleetPermissions? perms;
  final VoidCallback? onSwitchUi;

  const FxMonitoringPage({super.key, this.perms, this.onSwitchUi});

  @override
  State<FxMonitoringPage> createState() => _FxMonitoringPageState();
}

class _FxMonitoringPageState extends State<FxMonitoringPage> with TickerProviderStateMixin {
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
    return [if (p.overview) 'overview', if (p.fuel) 'fuel', if (p.concrete) 'concrete'].indexOf(key);
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
    final t = FxTokens.of(context);
    final p = _perms;
    final tabs = <({IconData icon, String label})>[];
    final views = <Widget>[];
    if (p != null) {
      if (p.overview) {
        tabs.add((icon: Icons.space_dashboard_rounded, label: 'Tổng quan'));
        views.add(FxOverviewTab(perms: p, onOpenFuel: p.fuel ? _openFuel : null, onOpenConcrete: p.concrete ? _openConcrete : null));
      }
      if (p.fuel) {
        tabs.add((icon: Icons.local_gas_station_rounded, label: 'Nhiên liệu'));
        views.add(FxFuelTab(request: _fuelRequest));
      }
      if (p.concrete) {
        tabs.add((icon: Icons.blender_rounded, label: 'Bê tông thừa'));
        views.add(FxConcreteTab(perms: p, request: _concreteRequest));
      }
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 4.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giám sát xe', style: t.h1.copyWith(fontSize: 19.sp)),
            Text('Nhiên liệu CAN & bê tông thừa', style: t.tiny),
          ],
        ),
        actions: [
          if (widget.onSwitchUi != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: t.text),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              onSelected: (v) {
                if (v == 'old') widget.onSwitchUi!();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'old',
                  child: Row(children: [
                    Icon(Icons.history_rounded, size: 18.sp, color: t.textMuted),
                    SizedBox(width: 10.w),
                    const Text('Về giao diện cũ (toàn app)'),
                  ]),
                ),
              ],
            ),
        ],
        bottom: tabs.length > 1 && _tabs != null
            ? PreferredSize(
                preferredSize: Size.fromHeight(54.h),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 8.h),
                  child: Container(
                    height: 42.h,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: t.dark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(13.r),
                    ),
                    child: TabBar(
                      controller: _tabs,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(10.r),
                      indicator: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(10.r),
                        boxShadow: const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      labelColor: t.text,
                      unselectedLabelColor: t.textMuted,
                      labelPadding: EdgeInsets.zero,
                      labelStyle: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w500),
                      tabs: [
                        for (final tb in tabs)
                          Tab(
                            height: 36.h,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(tb.icon, size: 15.sp),
                              SizedBox(width: 5.w),
                              Flexible(child: Text(tb.label, overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: p == null
          ? (_failed
              ? FxEmpty(
                  icon: Icons.lock_outline_rounded,
                  title: 'Không tải được quyền truy cập',
                  action: FilledButton.tonal(
                    onPressed: () {
                      setState(() => _failed = false);
                      _loadPerms();
                    },
                    child: const Text('Thử lại'),
                  ),
                )
              : const FxLoadingView())
          : views.isEmpty
              ? const Center(
                  child: FxEmpty(
                    icon: Icons.lock_outline_rounded,
                    title: 'Bạn chưa được cấp quyền',
                    message: 'Liên hệ quản trị để được cấp quyền Giám sát xe.',
                  ),
                )
              : views.length == 1
                  ? views.first
                  : TabBarView(controller: _tabs, physics: const NeverScrollableScrollPhysics(), children: views),
    );
  }
}
