import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/features/reports/data/services/report_service.dart';
import 'package:nguyenanh/features/reports/presentation/v2/production_view_v2.dart';
import 'package:nguyenanh/features/reports/presentation/v2/vehicle_ranking_view_v2.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Báo cáo Vận tải" (v2). Permissions, data loading (tanker detection, chunked per-vehicle requests,
/// previous-period comparison, aggregation) and the Excel export are the same as v1 [ReportPage];
/// only the presentation changed.
class ReportPageV2 extends StatefulWidget {
  final Function(DateTime)? onNavigateTrips;
  const ReportPageV2({super.key, this.onNavigateTrips});

  @override
  State<ReportPageV2> createState() => _ReportPageV2State();
}

class _ReportPageV2State extends State<ReportPageV2> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService(ApiClient.dio);
  final VehicleService _vehicleService = VehicleService(ApiClient.dio);
  final UserManageService _userManageService = UserManageService();

  bool _canViewProduction = false;
  bool _isLoadingPerms = true;

  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  ProductionReportResponse? _reportData;
  ProductionReportResponse? _prevReportData;
  Set<int> _tankerVehicleIds = {};
  List<VehicleModel> _allVehicles = [];
  bool _isLoading = true;
  String _groupBy = 'day';

  Map<String, String> _getGroupByLabels(AppLocalizations l10n) {
    return {
      'day': l10n.byDay,
      'week': l10n.byWeek,
      'month': l10n.byMonth,
    };
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('user_role') ?? '';

    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[role] ?? [];
      if (mounted) {
        setState(() {
          _canViewProduction = role == 'admin' || myPerms.contains('/reports/production');
          _isLoadingPerms = false;
        });
        if (_canViewProduction) {
          _loadReport();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPerms = false);
      }
    }
  }

  DateTimeRange _buildPreviousRange(DateTimeRange current, String groupBy) {
    final days = current.end.difference(current.start).inDays + 1;
    if (groupBy == 'month') {
      // For month, we subtract the number of months in the range
      int months = (current.end.year - current.start.year) * 12 + current.end.month - current.start.month + 1;
      return DateTimeRange(
        start: DateTime(current.start.year, current.start.month - months, current.start.day),
        end: DateTime(current.end.year, current.end.month - months, current.end.day),
      );
    } else if (groupBy == 'week') {
      int weeks = (days / 7).ceil();
      return DateTimeRange(
        start: current.start.subtract(Duration(days: weeks * 7)),
        end: current.end.subtract(Duration(days: weeks * 7)),
      );
    } else {
      return DateTimeRange(
        start: current.start.subtract(Duration(days: days)),
        end: current.end.subtract(Duration(days: days)),
      );
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final to = DateFormat('yyyy-MM-dd').format(_dateRange.end);

      // 1. Get Vehicle Types & Vehicles (Same as React)
      final results = await Future.wait([
        _reportService.getVehicleTypes(),
        _vehicleService.getVehicles(),
      ]);

      final typeList = results[0];
      final allVehicles = results[1];
      debugPrint('[ReportPage] All Types: $typeList');

      // 2. Identify Tanker Type IDs
      final String targetKey = 'xe_bon';
      String norm(String s) {
        var str = s.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
        const withDia = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
        const withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
        for (int i = 0; i < withDia.length; i++) {
          str = str.replaceAll(withDia[i], withoutDia[i]);
        }
        return str;
      }

      final tankerTypeIds = typeList
          .where((t) => norm(t['vehicle_type_name'] ?? '') == targetKey)
          .map((t) => t['vehicle_type_id'] as int)
          .toSet();

      debugPrint('[ReportPage] Tanker Type IDs: $tankerTypeIds');

      // 3. Filter Tanker Vehicles
      final tankerVehicles = allVehicles.where((v) => tankerTypeIds.contains(v.vehicleTypeId)).toList();

      debugPrint('[ReportPage] Found ${tankerVehicles.length} tankers');

      // 4. Fetch Individual Reports in chunks to avoid 429 Too Many Requests
      final currentReports = <ProductionReportResponse>[];
      for (var i = 0; i < tankerVehicles.length; i += 5) {
        final chunk = tankerVehicles.skip(i).take(5);
        final res = await Future.wait(chunk.map((v) => _reportService.getProduction(
              vehicleId: v.vehicleId,
              from: from,
              to: to,
              groupBy: _groupBy,
            )));
        currentReports.addAll(res);
        if (i + 5 < tankerVehicles.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // 5. Fetch Previous Period Reports (for comparison)
      final prevRange = _buildPreviousRange(_dateRange, _groupBy);
      final prevFrom = DateFormat('yyyy-MM-dd').format(prevRange.start);
      final prevTo = DateFormat('yyyy-MM-dd').format(prevRange.end);

      final prevReports = <ProductionReportResponse>[];
      for (var i = 0; i < tankerVehicles.length; i += 5) {
        final chunk = tankerVehicles.skip(i).take(5);
        final res = await Future.wait(chunk.map((v) => _reportService.getProduction(
              vehicleId: v.vehicleId,
              from: prevFrom,
              to: prevTo,
              groupBy: _groupBy,
            )));
        prevReports.addAll(res);
        if (i + 5 < tankerVehicles.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      // 6. Aggregate
      final aggregatedCurrent = ProductionReportResponse.aggregate(currentReports, from, to, _groupBy);
      final aggregatedPrev = ProductionReportResponse.aggregate(prevReports, prevFrom, prevTo, _groupBy);

      setState(() {
        _reportData = aggregatedCurrent;
        _prevReportData = aggregatedPrev;
        _tankerVehicleIds = tankerVehicles.map<int>((v) => v.vehicleId).toSet();
        _allVehicles = allVehicles as List<VehicleModel>;
        _isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('[ReportPage] Load Error: $e\n$stack');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải báo cáo: $e')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                  surface: Theme.of(context).colorScheme.surface,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
      _loadReport();
    }
  }

  Future<void> _exportReport() async {
    final l10n = AppLocalizations.of(context)!;
    if (_reportData == null) return;
    // read before the async gaps (same value as v1, which read it right before sharing)
    final size = MediaQuery.of(context).size;

    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Báo cáo Sản lượng'];
      excel.delete('Sheet1');

      // Add Headers
      sheetObject.appendRow([
        TextCellValue('Ngày/Kỳ'),
        TextCellValue('Tổng chuyến'),
        TextCellValue('Hoàn thành'),
        TextCellValue('KM'),
      ]);

      // Add Series Data
      for (var item in _reportData!.series) {
        sheetObject.appendRow([
          TextCellValue(item.period),
          IntCellValue(item.totalOrders),
          IntCellValue(item.completed),
          DoubleCellValue(item.distanceKm),
        ]);
      }

      // Add Vehicle Ranking sheet
      Sheet vehicleSheet = excel['Xếp hạng xe'];
      vehicleSheet.appendRow([
        TextCellValue('Xe'),
        TextCellValue('Biển số'),
        TextCellValue('Tổng chuyến'),
        TextCellValue('Tổng KM'),
      ]);

      for (var vehicle in _reportData!.topVehicles) {
        vehicleSheet.appendRow([
          TextCellValue(vehicle.vehicleName),
          TextCellValue(vehicle.vehicleLicensePlate),
          IntCellValue(vehicle.totalOrders),
          DoubleCellValue(vehicle.totalDistanceKm),
        ]);
      }

      // Save file
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final fileName = 'Bao_cao_Van_tai_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
      final file = File('${directory.path}/$fileName');

      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: l10n.transportReport,
            sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
          ),
        );
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xuất báo cáo: $e')),
        );
      }
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = FxTokens.of(context);
    final df = DateFormat('dd/MM/yyyy');
    final groupLabel = _getGroupByLabels(l10n)[_groupBy] ?? '';

    final Widget body;
    if (_isLoadingPerms) {
      body = const _ReportSkeleton();
    } else if (!_canViewProduction) {
      body = Center(
        child: FxEmpty(
          icon: Icons.lock_outline_rounded,
          title: 'Không có quyền truy cập báo cáo',
          message: 'Liên hệ quản trị để được cấp quyền xem báo cáo sản lượng.',
          action: FilledButton.tonalIcon(
            onPressed: () {
              setState(() => _isLoadingPerms = true);
              _checkPermissions();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _isLoading ? 0.55 : 1,
              child: _buildFilters(t, l10n),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const _ReportSkeleton()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      ProductionViewV2(
                        report: _reportData,
                        prevReport: _prevReportData,
                        groupBy: _groupBy,
                        tankerVehicleIds: _tankerVehicleIds,
                        onNavigateTrips: widget.onNavigateTrips,
                        allVehicles: _allVehicles,
                        onRetry: _loadReport,
                      ),
                      VehicleRankingViewV2(report: _reportData),
                    ],
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16.w,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.transportReport, style: t.h1.copyWith(fontSize: 19.sp)),
            if (_canViewProduction)
              Text(
                '${df.format(_dateRange.start)} – ${df.format(_dateRange.end)} · $groupLabel',
                style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        bottom: _canViewProduction ? _buildTabs(t, l10n) : null,
      ),
      body: body,
    );
  }

  PreferredSizeWidget _buildTabs(FxTokens t, AppLocalizations l10n) {
    final tabs = [
      (icon: Icons.insights_rounded, label: l10n.production),
      (icon: Icons.emoji_events_outlined, label: l10n.vehicleRanking),
    ];
    return PreferredSize(
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
            controller: _tabController,
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tb.icon, size: 15.sp),
                      SizedBox(width: 5.w),
                      Flexible(child: Text(tb.label, overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(FxTokens t, AppLocalizations l10n) {
    final labels = _getGroupByLabels(l10n);
    const icons = {
      'day': Icons.today_rounded,
      'week': Icons.view_week_outlined,
      'month': Icons.calendar_month_outlined,
    };
    final df = DateFormat('dd/MM/yy');

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 10.h),
      child: Column(
        children: [
          Row(
            children: [
              // Date range chip
              Expanded(
                child: Material(
                  color: t.card,
                  borderRadius: BorderRadius.circular(12.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: _selectDateRange,
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 15.sp, color: t.ink(FxTokens.blue)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '${df.format(_dateRange.start)} – ${df.format(_dateRange.end)}',
                              style: t.h3.copyWith(fontSize: 12.5.sp, fontFeatures: FxTokens.tabular),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18.sp, color: t.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              // Export
              Tooltip(
                message: l10n.exportReportBtn,
                child: Material(
                  color: t.soft(FxTokens.blue),
                  borderRadius: BorderRadius.circular(12.r),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12.r),
                    onTap: _exportReport,
                    child: Container(
                      height: 42.h,
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: FxTokens.blue.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined, size: 17.sp, color: t.ink(FxTokens.blue)),
                          SizedBox(width: 6.w),
                          Text(
                            l10n.exportReportBtn,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: t.ink(FxTokens.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          FxSegmented<String>(
            dense: true,
            segments: [
              for (final e in labels.entries) FxSegment(e.key, e.value, icon: icons[e.key]),
            ],
            value: _groupBy,
            onChanged: (newValue) {
              if (newValue == _groupBy) return;
              setState(() => _groupBy = newValue);
              _loadReport();
            },
          ),
        ],
      ),
    );
  }
}

/// Loading placeholder shaped like the production tab (KPI grid, chart card, list card).
class _ReportSkeleton extends StatelessWidget {
  const _ReportSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var r = 0; r < 2; r++) ...[
          Row(children: [
            Expanded(child: FxSkeleton(height: 112.h, radius: 18)),
            SizedBox(width: 10.w),
            Expanded(child: FxSkeleton(height: 112.h, radius: 18)),
          ]),
          SizedBox(height: 10.h),
        ],
        SizedBox(height: 2.h),
        FxSkeleton(height: 330.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 200.h, radius: 18),
      ],
    );
  }
}
