import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_order_item.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class VehicleManagementPage extends StatefulWidget {
  final List<OrderModel> pendingOrders;
  final List<VehicleModel> vehicles;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<Station> stations;
  final DateTime? initialDate;

  const VehicleManagementPage({
    super.key,
    required this.pendingOrders,
    required this.vehicles,
    required this.vtrackingVehicles,
    required this.stations,
    this.initialDate,
  });

  @override
  State<VehicleManagementPage> createState() => _VehicleManagementPageState();
}

class _VehicleManagementPageState extends State<VehicleManagementPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final OrderService _orderService = OrderService(ApiClient.dio);
  DateTime _selectedDate = DateTime.now();
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.vehicles.isNotEmpty) {
      _loadOrders();
    }
  }

  @override
  void didUpdateWidget(covariant VehicleManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null && widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _selectedDate = widget.initialDate!;
      });
      _loadOrders();
    } else if (oldWidget.vehicles.isEmpty && widget.vehicles.isNotEmpty) {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final allOrders = await _orderService.getOrdersByDate(dateStr);

      final mixerIds = widget.vehicles.map((v) => v.vehicleId).toSet();
      const allowedStatuses = {'completed', 'running', 'transporting'};
      final filtered = allOrders
          .where(
              (o) => o.vehicles != null &&
                  allowedStatuses.contains(o.orderStatus) &&
                  mixerIds.contains(o.vehicles!.vehicleId))
          .toList();

      if (!mounted) return;
      setState(() {
        _orders = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    final excel = Excel.createExcel();
    final sheetName = DateFormat('dd-MM-yyyy').format(_selectedDate);
    final sheet = excel[sheetName];
    excel.delete('Sheet1');

    final headers = [
      'STT',
      'Bien so',
      'Ten xe',
      'Tram',
      'Trang thai',
      'Bat dau',
      'Ket thuc',
      'Thoi gian',
      'Km',
      'Lan dung',
    ];

    final headerStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final sortedOrders = List<OrderModel>.from(_orders)
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    for (var i = 0; i < sortedOrders.length; i++) {
      final order = sortedOrders[i];
      final row = i + 1;

      final vehicle = widget.vehicles
          .where((v) => v.vehicleId == order.vehicles?.vehicleId)
          .firstOrNull;

      String durationText = '';
      if (order.orderStartDatetime != null && order.orderEndDatetime != null) {
        final start = DateTime.tryParse(order.orderStartDatetime!);
        final end = DateTime.tryParse(order.orderEndDatetime!);
        if (start != null && end != null) {
          final diff = end.difference(start);
          final hours = diff.inHours;
          final mins = diff.inMinutes % 60;
          durationText = hours > 0
              ? '${hours}h${mins.toString().padLeft(2, '0')}m'
              : '${mins}m';
        }
      }

      String startTime = '';
      if (order.orderStartDatetime != null) {
        final dt = DateTime.tryParse(order.orderStartDatetime!);
        if (dt != null) startTime = DateFormat('HH:mm').format(dt.toLocal());
      }

      String endTime = '';
      if (order.orderEndDatetime != null) {
        final dt = DateTime.tryParse(order.orderEndDatetime!);
        if (dt != null) endTime = DateFormat('HH:mm').format(dt.toLocal());
      }

      final multi = order.orderMulti;
      final distanceKm = multi != null ? multi.distanceKm.toStringAsFixed(1) : '';
      final stopCount = multi != null ? '${multi.stopCount}' : '';

      String statusText;
      if (order.orderStatus == 'completed') {
        statusText = 'Hoan thanh';
      } else if (order.orderStatus == 'init') {
        statusText = 'Dang chay';
      } else {
        statusText = order.orderStatus;
      }

      final values = [
        TextCellValue('${i + 1}'),
        TextCellValue(order.vehicles?.vehicleLicensePlate ?? ''),
        TextCellValue(vehicle?.vehicleName ?? ''),
        TextCellValue(order.stations?.stationName ?? ''),
        TextCellValue(statusText),
        TextCellValue(startTime),
        TextCellValue(endTime),
        TextCellValue(durationText),
        TextCellValue(distanceKm),
        TextCellValue(stopCount),
      ];

      for (var col = 0; col < values.length; col++) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
            .value = values[col];
      }
    }

    sheet.setColumnWidth(0, 5);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 10);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 10);
    sheet.setColumnWidth(7, 10);
    sheet.setColumnWidth(8, 8);
    sheet.setColumnWidth(9, 10);

    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final dir = await getTemporaryDirectory();
    final fileName = 'chuyen_xe_$sheetName.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(fileBytes);

    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Chuyen xe $sheetName',
      sharePositionOrigin: Rect.fromLTWH(0, 0, size.width, size.height / 2),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadOrders();
    }
  }

  List<OrderModel> _ordersForVehicle(int vehicleId) {
    return _orders.where((o) => o.vehicles?.vehicleId == vehicleId).toList();
  }

  List<VehicleModel> get _sortedVehicles {
    final sorted = List<VehicleModel>.from(widget.vehicles);
    sorted.sort((a, b) {
      final aOrders = _ordersForVehicle(a.vehicleId);
      final bOrders = _ordersForVehicle(b.vehicleId);

      if (aOrders.isEmpty && bOrders.isEmpty) return 0;
      if (aOrders.isEmpty) return 1;
      if (bOrders.isEmpty) return -1;

      final aLatest = aOrders
          .map((o) => DateTime.tryParse(o.updatedAt ?? '') ?? DateTime(2000))
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final bLatest = bOrders
          .map((o) => DateTime.tryParse(o.updatedAt ?? '') ?? DateTime(2000))
          .reduce((a, b) => a.isAfter(b) ? a : b);

      return bLatest.compareTo(aLatest);
    });
    return sorted;
  }

  VtrackingVehicle? _findVtracking(VehicleModel vehicle) {
    return widget.vtrackingVehicles.cast<VtrackingVehicle?>().firstWhere(
          (v) =>
              v!.vehicleName == vehicle.vehicleName ||
              v.licensePlate == vehicle.vehicleLicensePlate,
          orElse: () => null,
        );
  }

  String _distanceToNearestStation(VtrackingVehicle v) {
    final type2Stations = widget.stations
        .where(
            (s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null)
        .toList();
    if (type2Stations.isEmpty) return '---';

    const distance = Distance();
    double minDist = double.infinity;

    for (final s in type2Stations) {
      final d = distance.as(
        LengthUnit.Meter,
        LatLng(v.latitude, v.longitude),
        LatLng(s.getLat!, s.getLng!),
      );
      if (d < minDist) minDist = d;
    }

    if (minDist >= 1000) {
      return '${(minDist / 1000).toStringAsFixed(1)} km';
    }
    return '${minDist.round()} m';
  }

  void _showVehiclePopup(VehicleModel vehicle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final vtracking = _findVtracking(vehicle);
    final vehicleOrders = _ordersForVehicle(vehicle.vehicleId);
    final iconColor = colorScheme.primary;

    final sortedOrders = List<OrderModel>.from(vehicleOrders)
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Header
                  Row(
                    children: [
                      Icon(Icons.local_shipping_rounded,
                          color: iconColor, size: 24.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.vehicleLicensePlate,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (vehicle.vehicleName.isNotEmpty &&
                                vehicle.vehicleName !=
                                    vehicle.vehicleLicensePlate)
                              Text(
                                vehicle.vehicleName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  // Scrollable body
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        Divider(color: colorScheme.outlineVariant),
                        SizedBox(height: 8.h),
                        if (vtracking != null && vtracking.hasPosition) ...[
                          _infoRow(
                            Icons.speed_rounded,
                            l10n.speedLabel,
                            '${vtracking.speed.toStringAsFixed(0)} km/h',
                            colorScheme,
                            theme,
                          ),
                          SizedBox(height: 10.h),
                          _infoRow(
                            Icons.radar_rounded,
                            l10n.distanceLabel,
                            _distanceToNearestStation(vtracking),
                            colorScheme,
                            theme,
                          ),
                          if (vtracking.geocoding.isNotEmpty) ...[
                            SizedBox(height: 10.h),
                            _infoRow(
                              Icons.location_on_outlined,
                              l10n.locationLabel,
                              vtracking.geocoding,
                              colorScheme,
                              theme,
                            ),
                          ],
                          SizedBox(height: 12.h),
                          Divider(color: colorScheme.outlineVariant),
                          SizedBox(height: 8.h),
                        ],
                        Row(
                          children: [
                            Icon(Icons.route_rounded,
                                size: 16.sp, color: colorScheme.primary),
                            SizedBox(width: 8.w),
                            Text(
                              l10n.tripsOnDate,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                '${vehicleOrders.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        if (sortedOrders.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Text(
                              l10n.noTripsForVehicle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        else
                          ...sortedOrders.map(
                              (order) => _tripItem(order, theme, colorScheme, l10n)),
                        SizedBox(height: 8.h),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      ColorScheme colorScheme, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.sp, color: colorScheme.onSurfaceVariant),
        SizedBox(width: 10.w),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _tripItem(
      OrderModel order, ThemeData theme, ColorScheme colorScheme, AppLocalizations l10n) {
    final isCompleted = order.orderStatus == 'completed';
    final isActive = order.orderStatus == 'collecting' ||
        order.orderStatus == 'transporting' ||
        order.orderStatus == 'running';

    Color accentColor;
    String statusText;
    if (isCompleted) {
      accentColor = const Color(0xFF10B981);
      statusText = l10n.completedStatus;
    } else if (isActive) {
      accentColor = const Color(0xFF0EA5E9);
      statusText = l10n.transportingStatus;
    } else if (order.orderStatus == 'collecting') {
      accentColor = const Color(0xFFF59E0B);
      statusText = l10n.collecting;
    } else if (order.orderStatus == 'init') {
      accentColor = colorScheme.outline;
      statusText = l10n.initStatus;
    } else {
      accentColor = colorScheme.primary;
      statusText = l10n.pendingOrders;
    }

    // Init time
    String? initTimeText;
    final initDt = DateTime.tryParse(order.orderInitDatetime);
    if (initDt != null) {
      final local = initDt.toLocal();
      initTimeText = '${local.hour} ${l10n.hours} ${local.minute.toString().padLeft(2, '0')} ${l10n.minutes}';
    }

    // Start → End time
    String? startTimeText;
    if (order.orderStartDatetime != null) {
      final dt = DateTime.tryParse(order.orderStartDatetime!);
      if (dt != null) startTimeText = DateFormat('HH:mm').format(dt.toLocal());
    }
    String? endTimeText;
    if (order.orderEndDatetime != null) {
      final dt = DateTime.tryParse(order.orderEndDatetime!);
      if (dt != null) endTimeText = DateFormat('HH:mm').format(dt.toLocal());
    }

    // Running duration
    String? runDurationText;
    if (order.orderStartDatetime != null && order.orderEndDatetime != null) {
      final start = DateTime.tryParse(order.orderStartDatetime!);
      final end = DateTime.tryParse(order.orderEndDatetime!);
      if (start != null && end != null) {
        final diffMins = end.difference(start).inMinutes;
        final h = diffMins ~/ 60;
        final m = diffMins % 60;
        runDurationText = h > 0 ? '$h ${l10n.hours} $m ${l10n.minutes}' : '$m ${l10n.minutes}';
      }
    }

    // Mixing duration
    String? mixDurationText;
    final mixInVal = order.orderMulti?.checkinTimeStation ?? order.checkinTimeStation;
    final mixOutVal = order.orderMulti?.checkoutTimeStation ?? order.checkoutTimeStation;
    if (mixInVal != null && mixOutVal != null) {
      final mixIn = DateTime.tryParse(mixInVal);
      final mixOut = DateTime.tryParse(mixOutVal);
      if (mixIn != null && mixOut != null) {
        final mixMins = mixOut.difference(mixIn).inMinutes;
        if (mixMins > 0) {
          final h = mixMins ~/ 60;
          final m = mixMins % 60;
          mixDurationText = h > 0 ? '$h ${l10n.hours} $m ${l10n.minutes}' : '$mixMins ${l10n.minutes}';
        }
      }
    }

    // Distance & stops
    final multi = order.orderMulti;
    String? distanceText;
    String? stopsText;
    if (multi != null) {
      if (multi.distanceKm > 0) distanceText = '${multi.distanceKm.toStringAsFixed(1)} km';
      if (multi.stopCount > 0) {
        if (multi.stopDurationSeconds > 0) {
          final stopMins = multi.stopDurationSeconds ~/ 60;
          stopsText = '${multi.stopCount} ${l10n.stopCountLabel} ($stopMins ${l10n.minutes})';
        } else {
          stopsText = '${multi.stopCount} ${l10n.stopCountLabel}';
        }
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 72.h,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Station tag + init time + status badge
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.factory_rounded,
                                size: 11.sp, color: accentColor),
                            SizedBox(width: 3.w),
                            Flexible(
                              child: Text(
                                order.stations?.stationName ?? '---',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                  fontSize: 10.sp,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (initTimeText != null) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.access_time_rounded,
                          size: 11.sp, color: colorScheme.onSurfaceVariant),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          initTimeText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          statusText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                            fontSize: 9.sp,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                // Row 2: Start → End + running duration
                if (startTimeText != null || runDurationText != null) ...[
                  SizedBox(height: 4.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 4.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (startTimeText != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_outline_rounded,
                                size: 11.sp, color: const Color(0xFF0EA5E9)),
                            SizedBox(width: 2.w),
                            Text(
                              startTimeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 10.sp,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3.w),
                              child: Text('→',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10.sp,
                                  )),
                            ),
                            if (endTimeText != null)
                              Text(
                                endTimeText,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.sp,
                                ),
                              )
                            else
                              SizedBox(
                                width: 10.w,
                                height: 10.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: const Color(0xFF0EA5E9),
                                ),
                              ),
                          ],
                        ),
                      if (runDurationText != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 11.sp, color: const Color(0xFFF59E0B)),
                            SizedBox(width: 2.w),
                            Text(
                              runDurationText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF59E0B),
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
                // Row 3: Mixing duration + distance + stops
                if (mixDurationText != null || distanceText != null || stopsText != null) ...[
                  SizedBox(height: 4.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 4.h,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (mixDurationText != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.blender_rounded,
                                size: 11.sp, color: const Color(0xFF8B5CF6)),
                            SizedBox(width: 2.w),
                            Text(
                              '${l10n.mixLabel}: $mixDurationText',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF8B5CF6),
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      if (distanceText != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten_rounded,
                                size: 11.sp,
                                color: colorScheme.onSurfaceVariant),
                            SizedBox(width: 2.w),
                            Text(
                              distanceText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      if (stopsText != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_circle_outline_rounded,
                                size: 11.sp,
                                color: colorScheme.onSurfaceVariant),
                            SizedBox(width: 2.w),
                            Text(
                              stopsText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          centerTitle: false,
          title: Text(
            l10n.tripManagement,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
            labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: l10n.vehicleQueue),
              Tab(text: l10n.dailyTrips),
            ],
          ),
          actions: [
            FilledButton.tonal(
              onPressed: _pickDate,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                visualDensity: VisualDensity.compact,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    isToday
                        ? l10n.today
                        : DateFormat('dd/MM').format(_selectedDate),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 4.w),
            IconButton(
              onPressed: _orders.isEmpty ? null : _exportExcel,
              icon: Icon(
                Icons.table_chart_outlined,
                size: 20.sp,
                color: _orders.isEmpty
                    ? colorScheme.outlineVariant
                    : colorScheme.primary,
              ),
              tooltip: 'Export Excel',
            ),
            SizedBox(width: 8.w),
          ],
        ),
        body: TabBarView(
          children: [
            _buildQueueTab(l10n, colorScheme, theme),
            _buildDailyTripsTab(l10n, colorScheme, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab(AppLocalizations l10n, ColorScheme colorScheme, ThemeData theme) {
    final sorted = List<OrderModel>.from(widget.pendingOrders)
      ..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    if (sorted.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 64.sp,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
              SizedBox(height: 16.h),
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
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        return HomeOrderItem(
          order: sorted[index],
          orderNumber: index + 1,
          vehicles: widget.vehicles,
        );
      },
    );
  }

  Widget _buildDailyTripsTab(AppLocalizations l10n, ColorScheme colorScheme, ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.vehicles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 48.sp,
                color: colorScheme.onSurface.withValues(alpha: 0.2)),
            SizedBox(height: 12.h),
            Text(
              l10n.noVehicles,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final totalAll = _sortedVehicles.length;
    final totalMixers = _sortedVehicles.where((v) => v.vehicleName.toUpperCase().startsWith('X')).length;
    final totalOthers = _sortedVehicles.where((v) => !v.vehicleName.toUpperCase().startsWith('X')).length;

    final query = _searchQuery.trim().toLowerCase();
    final filteredVehicles = _sortedVehicles.where((v) {
      final isMixer = v.vehicleName.toUpperCase().startsWith('X');
      if (_categoryFilter == 'mixer' && !isMixer) return false;
      if (_categoryFilter == 'other' && isMixer) return false;

      if (query.isEmpty) return true;
      return v.vehicleLicensePlate.toLowerCase().contains(query) ||
             v.vehicleName.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: l10n.searchVehicleHint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.outline, size: 20.sp),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 0.h),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(100.r),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              _buildCategoryPill('all', '${l10n.allFilter} ($totalAll)', theme, colorScheme),
              SizedBox(width: 8.w),
              _buildCategoryPill('mixer', '${l10n.mixerFilter} ($totalMixers)', theme, colorScheme),
              SizedBox(width: 8.w),
              _buildCategoryPill('other', '${l10n.otherFilter} ($totalOthers)', theme, colorScheme),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadOrders,
            child: filteredVehicles.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.only(top: 60.h),
                      child: Center(
                        child: Text(
                          l10n.noResultsFound,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredVehicles[index];
                      // To keep #index consistent with original list, maybe use indexOf?
                      // Or just use the new filtered index + 1
                      return _buildVehicleItem(
                          vehicle, _sortedVehicles.indexOf(vehicle), theme, colorScheme);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleItem(VehicleModel vehicle, int index, ThemeData theme,
      ColorScheme colorScheme) {
    final tripCount = _ordersForVehicle(vehicle.vehicleId).length;
    final iconColor = colorScheme.primary;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800.w),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () => _showVehiclePopup(vehicle),
              child: Row(
                children: [
                  // Accent bar like HomeOrderItem
                  Container(
                    width: 4.w,
                    height: 64.h,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12.r),
                        bottomLeft: Radius.circular(12.r),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    vehicle.vehicleName.isNotEmpty
                                        ? vehicle.vehicleName
                                        : '#${index + 1}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: iconColor,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                vehicle.vehicleLicensePlate,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (tripCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$tripCount',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: iconColor,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    l10n.trips,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: iconColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              l10n.noTripsYet,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          SizedBox(width: 8.w),
                          Icon(Icons.chevron_right_rounded,
                              size: 20.sp, color: colorScheme.outlineVariant),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String filterType, String label, ThemeData theme, ColorScheme colorScheme) {
    final isSelected = _categoryFilter == filterType;
    final primaryColor = colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: () => setState(() => _categoryFilter = filterType),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? Colors.transparent : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(Icons.check_rounded, color: Colors.white, size: 14.sp),
                SizedBox(width: 4.w),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
