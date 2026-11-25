import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/v2/parking_idle_engine_detail_sheet_v2.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/v2/parking_idle_engine_settings_dialog_v2.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/v2/pie_v2_shared.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';

/// "Giám sát nổ máy trong bãi" (v2). Same data loading, 30 s auto refresh, permission check, search,
/// "warning only" filter and sorting as [ParkingIdleEngineDashboardPage]; only the presentation is new.
class ParkingIdleEngineDashboardPageV2 extends StatefulWidget {
  const ParkingIdleEngineDashboardPageV2({super.key});

  @override
  State<ParkingIdleEngineDashboardPageV2> createState() => _ParkingIdleEngineDashboardPageV2State();
}

class _ParkingIdleEngineDashboardPageV2State extends State<ParkingIdleEngineDashboardPageV2> {
  final ParkingIdleEngineService _apiService = ParkingIdleEngineService();
  final UserManageService _userService = UserManageService();
  final TextEditingController _searchController = TextEditingController();

  ParkingIdleEngineAlertsResponse? _dashboardData;
  bool _isLoading = true;
  bool _warningOnly = false;
  bool _canSettings = false;
  String _searchQuery = '';
  Timer? _refreshTimer;

  // presentation only
  bool _failed = false;
  DateTime? _updatedAt;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _fetchData();
    _checkPermissions();
    // Auto refresh every 30 seconds like React
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchData(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? '';
      final perms = await _userService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canSettings = role == 'admin' || myPerms.contains('/parking-idle-engine__settings');
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final res = await _apiService.getAlerts(warningOnly: _warningOnly);
      if (mounted) {
        setState(() {
          _dashboardData = res;
          _isLoading = false;
          _failed = false;
          _updatedAt = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải dữ liệu giám sát nổ máy')),
        );
      }
    }
  }

  List<ParkingIdleEngineAlert> get _filteredAndSortedItems {
    if (_dashboardData == null) return [];
    var items = List<ParkingIdleEngineAlert>.from(_dashboardData!.items);

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      items = items
          .where((i) => i.vehicleName.toLowerCase().contains(q) || i.vehicleLicensePlate.toLowerCase().contains(q))
          .toList();
    }

    items.sort((a, b) {
      // 1. In yard > Not in yard
      if (a.inYard && !b.inYard) return -1;
      if (!a.inYard && b.inYard) return 1;

      // 2. Engine ON > Engine OFF
      if (a.engineState == 'on' && b.engineState != 'on') return -1;
      if (a.engineState != 'on' && b.engineState == 'on') return 1;

      // 3. Sort by elapsed minutes descending
      return b.elapsedMinutes.compareTo(a.elapsedMinutes);
    });

    return items;
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) => ParkingIdleEngineSettingsDialogV2(
        apiService: _apiService,
        onSaveSuccess: () => _fetchData(),
      ),
    );
  }

  void _setWarningOnly(bool v) {
    if (v == _warningOnly) return;
    setState(() {
      _warningOnly = v;
    });
    _fetchData();
  }

  double _thresholdOf(ParkingIdleEngineAlert a) =>
      a.warningAfterMinutes > 0 ? a.warningAfterMinutes : (_dashboardData?.settings.warningAfterMinutes ?? 0);

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final items = _filteredAndSortedItems;
    final data = _dashboardData;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 60.h,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giám sát nổ máy', style: t.h1.copyWith(fontSize: 18.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2.h),
            Text(
              _updatedAt == null
                  ? 'Xe bồn trong bãi · tự làm mới mỗi 30 giây'
                  : 'Xe bồn trong bãi · cập nhật ${DateFormat('HH:mm:ss').format(_updatedAt!)}',
              style: t.small.copyWith(fontWeight: FontWeight.w500, fontFeatures: FxTokens.tabular),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            icon: Icon(Icons.refresh_rounded, color: t.text),
            onPressed: () => _fetchData(),
          ),
          if (_canSettings)
            IconButton(
              tooltip: 'Cấu hình cảnh báo',
              icon: Icon(Icons.tune_rounded, color: t.text),
              onPressed: _openSettings,
            ),
          SizedBox(width: 6.w),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _fetchData(showLoading: false),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
              sliver: SliverList.list(
                children: [
                  _kpis(t, data),
                  if (data != null && !data.settings.enabled)
                    const FxBanner(
                      tone: FxTokens.amber,
                      icon: Icons.notifications_off_outlined,
                      title: 'Cảnh báo nổ máy đang tắt',
                      text: 'Cấu hình hiện tại đang tắt cảnh báo xe nổ máy trong bãi.',
                    ),
                  _controls(t, data),
                  Padding(
                    padding: EdgeInsets.only(left: 2.w, bottom: 10.h, top: 2.h),
                    child: Row(
                      children: [
                        Expanded(child: Text('DANH SÁCH XE BỒN', style: t.overline)),
                        Text(
                          '${items.length} xe · Nhấn để xem lịch sử',
                          style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ..._listSlivers(t, items),
            SliverToBoxAdapter(child: SizedBox(height: 28.h + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  Widget _kpis(FxTokens t, ParkingIdleEngineAlertsResponse? data) {
    if (data == null && _isLoading) {
      return FxGrid(
        columns: 2,
        children: [for (var i = 0; i < 4; i++) FxSkeleton(height: 104.h, radius: 18)],
      );
    }
    String v(int? n) => data == null ? '—' : '${n ?? 0}';
    final thr = data?.settings.warningAfterMinutes ?? 0;
    final fuel = data?.estimatedIdleFuelLiters ?? 0;
    return FxGrid(
      columns: 2,
      children: [
        FxKpi(
          icon: Icons.local_shipping_rounded,
          label: 'Tổng xe bồn',
          value: v(data?.totalVehicles),
          unit: 'xe',
          tone: FxTokens.indigo,
          hint: 'Tổng số xe bồn đang được hệ thống giám sát.',
        ),
        FxKpi(
          icon: Icons.pin_drop_rounded,
          label: 'Xe trong bãi',
          value: v(data?.inYardCount),
          unit: 'xe',
          tone: FxTokens.blue,
          hint: 'Số xe bồn đang nằm trong khu vực bãi.',
        ),
        FxKpi(
          icon: Icons.bolt_rounded,
          label: 'Đang nổ máy',
          value: v(data?.engineOnCount),
          unit: 'xe',
          sub: fuel > 0 ? '≈ ${pieFmtNum(fuel, 1)} L nhiên liệu ước tính' : null,
          tone: FxTokens.amber,
          hint: 'Số xe trong bãi đang nổ máy (đứng yên nhưng động cơ vẫn chạy).',
        ),
        FxKpi(
          icon: Icons.warning_amber_rounded,
          label: 'Đang cảnh báo',
          value: v(data?.warningCount),
          unit: 'xe',
          sub: thr > 0 ? 'Ngưỡng ${pieFmtNum(thr, 0)} phút' : null,
          tone: FxTokens.red,
          hint: 'Số xe nổ máy trong bãi lâu hơn ngưỡng cảnh báo đã cấu hình.',
        ),
      ],
    );
  }

  Widget _controls(FxTokens t, ParkingIdleEngineAlertsResponse? data) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: t.border));
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            style: t.body,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm xe, biển số...',
              hintStyle: t.small,
              prefixIcon: Icon(Icons.search_rounded, color: t.textFaint, size: 20.sp),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: Icon(Icons.close_rounded, size: 18.sp, color: t.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: t.card,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: FxTokens.blue, width: 1.4),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
          SizedBox(height: 10.h),
          FxSegmented<bool>(
            segments: [
              const FxSegment(false, 'Tất cả xe', icon: Icons.local_shipping_outlined),
              FxSegment(true, 'Chỉ cảnh báo', icon: Icons.warning_amber_rounded, badge: data?.warningCount),
            ],
            value: _warningOnly,
            onChanged: _setWarningOnly,
          ),
        ],
      ),
    );
  }

  List<Widget> _listSlivers(FxTokens t, List<ParkingIdleEngineAlert> items) {
    final pad = EdgeInsets.symmetric(horizontal: 16.w);
    if (_isLoading) {
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverList.list(
            children: [
              for (var i = 0; i < 4; i++) ...[
                FxSkeleton(height: 132.h, radius: 18),
                SizedBox(height: 10.h),
              ],
            ],
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      final Widget empty;
      if (_failed && _dashboardData == null) {
        empty = FxEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Không thể tải dữ liệu giám sát nổ máy',
          message: 'Kiểm tra kết nối mạng rồi thử lại.',
          action: FilledButton.tonalIcon(
            onPressed: () => _fetchData(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        );
      } else if (_searchQuery.isNotEmpty) {
        empty = const FxEmpty(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy xe phù hợp',
          message: 'Thử tìm theo tên xe hoặc biển số khác.',
        );
      } else {
        empty = FxEmpty(
          icon: _warningOnly ? Icons.verified_outlined : Icons.local_shipping_outlined,
          title: 'Không có xe nào',
          message: _warningOnly ? 'Hiện không có xe nào đang cảnh báo.' : null,
        );
      }
      return [
        SliverPadding(
          padding: pad,
          sliver: SliverToBoxAdapter(child: FxCard(child: Center(child: empty))),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: pad,
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, idx) {
            final alert = items[idx];
            return _VehicleCard(
              key: ValueKey('pie-${alert.vehicleId}'),
              alert: alert,
              thresholdMinutes: _thresholdOf(alert),
              onTap: () => ParkingIdleEngineDetailSheetV2.show(context, alert, _apiService),
            );
          },
        ),
      ),
    ];
  }
}

class _VehicleCard extends StatelessWidget {
  final ParkingIdleEngineAlert alert;
  final double thresholdMinutes;
  final VoidCallback onTap;

  const _VehicleCard({super.key, required this.alert, required this.thresholdMinutes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final warn = alert.warningActive && alert.inYard;
    final tone = pieToneOf(alert);

    final card = FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      onTap: onTap,
      color: warn ? Color.alphaBlend(FxTokens.red.withValues(alpha: t.dark ? 0.10 : 0.035), t.card) : null,
      borderColor: warn ? FxTokens.red.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FxIconBadge(
                icon: Icons.local_shipping_rounded,
                tone: alert.inYard ? (tone == FxTokens.slate ? FxTokens.indigo : tone) : FxTokens.slate,
                size: 38,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.vehicleName,
                      style: t.h3.copyWith(fontSize: 14.5.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      alert.vehicleLicensePlate,
                      style: t.small.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              if (alert.inYard) PieWarningPill(warning: alert.warningActive) else Text('—', style: t.small),
              SizedBox(width: 2.w),
              Icon(Icons.chevron_right_rounded, size: 20.sp, color: t.textFaint),
            ],
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              PieYardPill(inYard: alert.inYard),
              if (alert.inYard) PieEnginePill(alert: alert),
            ],
          ),
          if (alert.inYard) ...[
            SizedBox(height: 10.h),
            PieLiveElapsed(
              idleStartedAt: alert.idleStartedAt,
              fallbackMinutes: alert.elapsedMinutes,
              builder: (context, secs) => PieElapsedMeter(alert: alert, seconds: secs, thresholdMinutes: thresholdMinutes),
            ),
          ],
        ],
      ),
    );

    return alert.inYard ? card : Opacity(opacity: 0.6, child: card);
  }
}
