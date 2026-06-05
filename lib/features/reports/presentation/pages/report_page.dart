import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/features/reports/data/services/report_service.dart';
import 'package:nguyenanh/features/reports/presentation/widgets/production_view.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/reports/presentation/widgets/vehicle_ranking_view.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class ReportPage extends StatefulWidget {
  final Function(DateTime)? onNavigateTrips;
  const ReportPage({super.key, this.onNavigateTrips});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> with SingleTickerProviderStateMixin {
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

      final typeList = results[0] as List<dynamic>;
      final allVehicles = results[1] as List<dynamic>;
      debugPrint('[ReportPage] All Types: $typeList');

      // 2. Identify Tanker Type IDs
      final String targetKey = "xe_bon";
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
      final tankerVehicles = allVehicles
          .where((v) => tankerTypeIds.contains(v.vehicleTypeId))
          .toList();
      
      debugPrint('[ReportPage] Found ${tankerVehicles.length} tankers');

      // 4. Fetch Individual Reports in parallel
      final currentReports = await Future.wait(tankerVehicles.map((v) => _reportService.getProduction(
            vehicleId: v.vehicleId,
            from: from,
            to: to,
            groupBy: _groupBy,
          )));

      // 5. Fetch Previous Period Reports (for comparison)
      final prevRange = _buildPreviousRange(_dateRange, _groupBy);
      final prevFrom = DateFormat('yyyy-MM-dd').format(prevRange.start);
      final prevTo = DateFormat('yyyy-MM-dd').format(prevRange.end);

      final prevReports = await Future.wait(tankerVehicles.map((v) => _reportService.getProduction(
            vehicleId: v.vehicleId,
            from: prevFrom,
            to: prevTo,
            groupBy: _groupBy,
          )));

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
        final size = MediaQuery.of(context).size;
        await Share.shareXFiles(
          [XFile(file.path)], 
          text: l10n.transportReport,
          sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          l10n.transportReport,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: _canViewProduction ? [
          IconButton(
            onPressed: _exportReport,
            icon: Icon(Icons.download_rounded, color: colorScheme.primary),
            tooltip: l10n.exportReportBtn,
          ),
          SizedBox(width: 8.w),
        ] : null,
        bottom: _canViewProduction ? TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: l10n.production),
            Tab(text: l10n.vehicleRanking),
          ],
        ) : null,
      ),
      body: _isLoadingPerms || _isLoading
          ? Center(child: CircularProgressIndicator())
          : (!_canViewProduction)
              ? Center(child: Text('Không có quyền truy cập báo cáo', style: theme.textTheme.titleMedium))
              : Column(
                  children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 800.w),
                    child: Container(
                      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Date Picker Button
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: _selectDateRange,
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '${DateFormat('dd/MM/yy').format(_dateRange.start)} - ${DateFormat('dd/MM/yy').format(_dateRange.end)}',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(width: 4.w),
                                      Icon(Icons.keyboard_arrow_down_rounded, size: 16.sp),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              // GroupBy Selection
                              Expanded(
                                flex: 3,
                                child: Container(
                                  height: 38.h,
                                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _groupBy,
                                      isExpanded: true,
                                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18.sp, color: colorScheme.primary),
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary,
                                      ),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() => _groupBy = newValue);
                                          _loadReport();
                                        }
                                      },
                                      items: _getGroupByLabels(l10n).entries.map((entry) {
                                        return DropdownMenuItem<String>(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Export Button - Matching Home style
                              Expanded(
                                flex: 4,
                                child: OutlinedButton.icon(
                                  onPressed: _exportReport,
                                  icon: Icon(Icons.description_outlined, size: 16.sp),
                                  label: Text(l10n.exportReportBtn),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colorScheme.primary,
                                    side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                    minimumSize: Size(0, 38.h),
                                    textStyle: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Main Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ProductionView(
                        report: _reportData,
                        prevReport: _prevReportData,
                        groupBy: _groupBy,
                        tankerVehicleIds: _tankerVehicleIds,
                        onNavigateTrips: widget.onNavigateTrips,
                        allVehicles: _allVehicles,
                      ),
                      VehicleRankingView(report: _reportData),
                    ],
                  ),
                ),
                  ],
                ),
    );
  }
}
