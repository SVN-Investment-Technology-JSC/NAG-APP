import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_order_item.dart';
import 'package:nguyenanh/features/home/presentation/widgets/vehicle_detail_sheet.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/shell/presentation/main_shell.dart';
import 'package:nguyenanh/features/notifications/presentation/widgets/notification_bottom_sheet.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class VehicleManagementPage extends StatefulWidget {
  final List<OrderModel> pendingOrders;
  final List<VehicleModel> vehicles;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<Station> stations;
  final DateTime? initialDate;
  final VoidCallback? onRefresh;
  final NotificationSocketService notificationService;

  const VehicleManagementPage({
    super.key,
    required this.pendingOrders,
    required this.vehicles,
    required this.vtrackingVehicles,
    required this.stations,
    required this.notificationService,
    this.initialDate,
    this.onRefresh,
  });

  @override
  State<VehicleManagementPage> createState() => _VehicleManagementPageState();
}

class _VehicleManagementPageState extends State<VehicleManagementPage> with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  final OrderService _orderService = OrderService(ApiClient.dio);
  final VehicleService _vehicleService = VehicleService(ApiClient.dio);
  DateTime _selectedDate = DateTime.now();
  List<OrderModel> _orders = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = 'all';
  
  final UserManageService _userManageService = UserManageService();
  String _userRole = '';
  bool _canManualSort = false;
  bool _canOrderDetail = false;
  bool _isManualMode = false;
  bool _isReordering = false;
  late AnimationController _reloadAnimController;

  @override
  void dispose() {
    _searchController.dispose();
    _reloadAnimController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reloadAnimController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _loadUserInfo();
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

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userRole = prefs.getString('user_role') ?? '';
    });

    try {
      final perms = await _userManageService.getPermissions();
      final myPerms = perms[_userRole] ?? [];
      if (mounted) {
        setState(() {
          _canManualSort = _userRole == 'admin' || myPerms.contains('/dashboard__manual_sort');
          _canOrderDetail = _userRole == 'admin' || myPerms.contains('/dashboard__order_detail');
        });
      }
    } catch (_) {}
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
    if (!_canOrderDetail && _userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xem chi tiết các chuyến xe (đơn hàng)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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

    final statusOptions = [
      {
        'value': 'available',
        'label': l10n.statusAvailable,
        'icon': Icons.check_circle_outline_rounded,
        'activeColor': const Color(0xFF047857), // emerald-700
        'activeBg': const Color(0xFFECFDF5),    // emerald-50
        'activeBorder': const Color(0xFF34D399), // emerald-400
      },
      {
        'value': 'incident',
        'label': l10n.statusIncident,
        'icon': Icons.warning_amber_rounded,
        'activeColor': const Color(0xFFB91C1C), // red-700
        'activeBg': const Color(0xFFFEF2F2),    // red-50
        'activeBorder': const Color(0xFFF87171), // red-400
      },
      {
        'value': 'maintenance',
        'label': l10n.statusMaintenance,
        'icon': Icons.construction_rounded,
        'activeColor': const Color(0xFFB45309), // amber-700
        'activeBg': const Color(0xFFFFFBEB),    // amber-50
        'activeBorder': const Color(0xFFFBBF24), // amber-400
      },
      {
        'value': 'other',
        'label': l10n.statusOther,
        'icon': Icons.help_outline_rounded,
        'activeColor': const Color(0xFF6B21A8), // purple-700
        'activeBg': const Color(0xFFFAF5FF),    // purple-50
        'activeBorder': const Color(0xFFC084FC), // purple-400
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        String baselineStatus = vehicle.vehicleStatus;
        bool isUpdating = false;

        return StatefulBuilder(
          builder: (context, setStatePopup) {

            void showStatusSelectorDialog({
              required BuildContext context,
              required String currentStatus,
              required List<Map<String, dynamic>> statusOptions,
              required AppLocalizations l10n,
              required ThemeData theme,
              required ColorScheme colorScheme,
              required Function(String) onSave,
            }) {
              showDialog(
                context: context,
                builder: (dialogCtx) {
                  String tempSelectedStatus = currentStatus;
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    title: Text(
                      l10n.confirmChangeStatus,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: statusOptions.map((opt) {
                            final isSelected = tempSelectedStatus == opt['value'];
                            final activeColor = opt['activeColor'] as Color;
                            final activeBg = opt['activeBg'] as Color;
                            final activeBorder = opt['activeBorder'] as Color;
                            final icon = opt['icon'] as IconData;
                            final label = opt['label'] as String;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: InkWell(
                                onTap: () {
                                  setStateDialog(() {
                                    tempSelectedStatus = opt['value'] as String;
                                  });
                                },
                                borderRadius: BorderRadius.circular(12.r),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                  decoration: BoxDecoration(
                                    color: isSelected ? activeBg : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? activeBorder : colorScheme.outlineVariant,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        icon,
                                        size: 20.sp,
                                        color: isSelected ? activeColor : colorScheme.onSurfaceVariant,
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Text(
                                          label,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? activeColor : colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: activeColor,
                                          size: 18.sp,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text(
                          l10n.cancel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          onSave(tempSelectedStatus);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7), // sky-600
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        child: Text(
                          "Lưu",
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            }

            Widget buildCurrentStatusBadge(String statusVal) {
              final opt = statusOptions.firstWhere(
                (o) => o['value'] == statusVal,
                orElse: () => statusOptions[0],
              );
              final activeColor = opt['activeColor'] as Color;
              final activeBg = opt['activeBg'] as Color;
              final label = opt['label'] as String;

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: activeBg,
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(color: activeColor.withOpacity(0.2)),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: activeColor,
                    fontSize: 10.sp,
                  ),
                ),
              );
            }

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
                                Row(
                                  children: [
                                    Text(
                                      vehicle.vehicleLicensePlate,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    buildCurrentStatusBadge(baselineStatus),
                                  ],
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
                      SizedBox(height: 16.h),
                      // Current Status Selector Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? colorScheme.surfaceContainerLow
                              : const Color(0xFFF8FAFC), // slate-50
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "Trạng thái xe",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () => showStatusSelectorDialog(
                                            context: context,
                                            currentStatus: baselineStatus,
                                            statusOptions: statusOptions,
                                            l10n: l10n,
                                            theme: theme,
                                            colorScheme: colorScheme,
                                            onSave: (newStatus) async {
                                              setStatePopup(() => isUpdating = true);
                                              try {
                                                final success = await _vehicleService.updateVehicleStatus(
                                                  vehicle.vehicleId,
                                                  newStatus,
                                                );
                                                if (success) {
                                                  baselineStatus = newStatus;
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(l10n.updateStatusSuccess(vehicle.vehicleLicensePlate)),
                                                        backgroundColor: Colors.green,
                                                      ),
                                                    );
                                                  }
                                                  widget.onRefresh?.call();
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(l10n.updateStatusFailed),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(l10n.updateStatusFailed),
                                                      backgroundColor: Colors.red,
                                                    ),
                                                  );
                                                }
                                              } finally {
                                                if (context.mounted) {
                                                  setStatePopup(() => isUpdating = false);
                                                }
                                              }
                                            },
                                          ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0284C7), // sky-600
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isUpdating
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.w,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : Text(
                                          "Cập nhật",
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            // Info alert box
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF), // blue-50
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(color: const Color(0xFFBFDBFE)), // blue-200
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 16.sp,
                                    color: const Color(0xFF1D4ED8), // blue-700
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      "Nhấn vào nút Cập nhật để thay đổi trạng thái xe hoặc báo cáo sự cố.",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF1E40AF), // blue-800
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16.r),
                                child: VehicleMapWidget(
                                  vtracking: vtracking,
                                  stations: widget.stations,
                                ),
                              ),
                              SizedBox(height: 16.h),
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
            NotificationBadge(notificationService: widget.notificationService),
            SizedBox(width: 8.w),
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

    return Stack(
      children: [
        Column(
          children: [
            if (_canManualSort && sorted.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.onRefresh != null)
                      RotationTransition(
                        turns: _reloadAnimController,
                        child: IconButton(
                          icon: Icon(Icons.refresh_rounded, size: 20.sp, color: colorScheme.primary),
                          onPressed: () {
                            if (widget.onRefresh != null) widget.onRefresh!();
                            _reloadAnimController.forward(from: 0.0);
                          },
                          tooltip: 'Tải lại',
                        ),
                      ),
                    SizedBox(width: 4.w),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isManualMode = false),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: !_isManualMode ? colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.horizontal(left: Radius.circular(7.r)),
                              ),
                              child: Text(
                                'AUTO',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: !_isManualMode ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _isManualMode = true),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: _isManualMode ? colorScheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(7.r)),
                              ),
                              child: Text(
                                'MANUAL',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _isManualMode ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: sorted.isEmpty
                  ? Padding(
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
                    )
                  : (_isManualMode
                      ? ReorderableListView.builder(
                          padding: EdgeInsets.only(top: _canManualSort ? 4.h : 16.h, bottom: 24.h),
                          itemCount: sorted.length,
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) newIndex -= 1;
                            if (oldIndex == newIndex) return;

                            final order = sorted[oldIndex];
                            final targetOrderNumber = newIndex + 1;

                            setState(() => _isReordering = true);
                            try {
                              await _orderService.updateOrderNumber(order.orderId, targetOrderNumber);
                              // Assuming a refresh might happen via socket or we can call some refresh function
                              // Note: There's no onRefresh prop passed directly here, so we might rely on the main shell/socket to update pendingOrders.
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi khi sắp xếp: $e')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _isReordering = false);
                            }
                          },
                          itemBuilder: (context, index) {
                            return ReorderableDelayedDragStartListener(
                              key: ValueKey(sorted[index].orderId),
                              index: index,
                              child: GestureDetector(
                                onTap: () => _showEditOrderNumberDialog(sorted[index], index + 1),
                                child: HomeOrderItem(
                                  order: sorted[index],
                                  orderNumber: index + 1,
                                  vehicles: widget.vehicles,
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(top: _canManualSort ? 4.h : 16.h, bottom: 24.h),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            return HomeOrderItem(
                              order: sorted[index],
                              orderNumber: index + 1,
                              vehicles: widget.vehicles,
                            );
                          },
                        )),
            ),
          ],
        ),
        if (_isReordering)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
      ],
    );
  }

  void _showEditOrderNumberDialog(OrderModel order, int currentNumber) {
    final TextEditingController controller = TextEditingController(text: currentNumber.toString());
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text('Đổi thứ tự lốt xe',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nhập số thứ tự mới',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () async {
                final newNumber = int.tryParse(controller.text);
                if (newNumber != null && newNumber != currentNumber) {
                  Navigator.pop(context);
                  setState(() => _isReordering = true);
                  try {
                    await _orderService.updateOrderNumber(order.orderId, newNumber);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khi cập nhật thứ tự: $e')),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isReordering = false);
                  }
                } else {
                  Navigator.pop(context);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
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
              _buildCategoryPill('all', '${l10n.allFilter} ($totalAll)', theme, colorScheme, activeColor: const Color(0xFF334155)),
              SizedBox(width: 8.w),
              _buildCategoryPill('mixer', '${l10n.mixerFilter} ($totalMixers)', theme, colorScheme, activeColor: colorScheme.primary),
              SizedBox(width: 8.w),
              _buildCategoryPill('other', '${l10n.otherFilter} ($totalOthers)', theme, colorScheme, activeColor: const Color(0xFF0EA5E9)),
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
    final isMixer = vehicle.vehicleName.toUpperCase().startsWith('X');
    final iconColor = isMixer ? colorScheme.primary : const Color(0xFF0EA5E9);

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

  Widget _buildCategoryPill(String filterType, String label, ThemeData theme, ColorScheme colorScheme, {Color? activeColor}) {
    final isSelected = _categoryFilter == filterType;
    final primaryColor = activeColor ?? colorScheme.primary;

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

class VehicleMapWidget extends StatefulWidget {
  final VtrackingVehicle vtracking;
  final List<Station> stations;
  final bool isFullscreen;

  const VehicleMapWidget({
    super.key,
    required this.vtracking,
    required this.stations,
    this.isFullscreen = false,
  });

  @override
  State<VehicleMapWidget> createState() => _VehicleMapWidgetState();
}

class _VehicleMapWidgetState extends State<VehicleMapWidget> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final center = LatLng(widget.vtracking.latitude, widget.vtracking.longitude);

    final circles = widget.stations
        .where((s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null)
        .map((s) => CircleMarker(
              point: LatLng(s.getLat!, s.getLng!),
              radius: s.stationGpsGeofencing.toDouble(),
              useRadiusInMeter: true,
              color: const Color(0x1406B6D4),
              borderColor: const Color(0xFF06B6D4),
              borderStrokeWidth: 1.5,
            ))
        .toList();

    Widget carSvg = SvgPicture.asset(
      'assets/images/car.svg',
      width: 36.w,
      height: 36.w,
      fit: BoxFit.contain,
    );

    if (widget.vtracking.status == 'stop' || widget.vtracking.status == 'park') {
      carSvg = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0, 0, 1, 0, 0, // R' = B
          0, 1, 0, 0, 0, // G' = G
          1, 0, 0, 0, 0, // B' = R
          0, 0, 0, 1, 0, // A' = A
        ]),
        child: carSvg,
      );
    } else if (widget.vtracking.status == 'offline') {
      carSvg = Opacity(
        opacity: 0.6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: carSvg,
        ),
      );
    }

    final marker = Marker(
      point: center,
      width: 80.w,
      height: 80.w,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => VehicleDetailSheet.show(context, widget.vtracking, widget.stations),
            child: Transform.rotate(
              angle: widget.vtracking.direction * (3.1415926535897932 / 180),
              child: carSvg,
            ),
          ),
          Positioned(
            bottom: 48.w + 2.h,
            child: GestureDetector(
              onTap: () => VehicleDetailSheet.show(context, widget.vtracking, widget.stations),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.vtracking.vehicleName.isNotEmpty ? widget.vtracking.vehicleName : '---',
                      style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 10.sp),
                    ),
                    if (widget.vtracking.licensePlate.isNotEmpty)
                      Text(
                        widget.vtracking.licensePlate,
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 8.sp, color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget mapStack = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 16, maxZoom: 20.0),
          children: [
            TileLayer(
              urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.nguyenanh.nagapp',
            ),
            CircleLayer(circles: circles),
            MarkerLayer(markers: [marker]),
          ],
        ),
        Positioned(
          bottom: 8.h,
          left: 8.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                margin: EdgeInsets.only(bottom: 4.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20.sp,
                  icon: Icon(Icons.add_rounded, color: colorScheme.onSurface),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                ),
              ),
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20.sp,
                  icon: Icon(Icons.remove_rounded, color: colorScheme.onSurface),
                  onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 8.h,
          right: 8.w,
          child: FilledButton.tonalIcon(
            onPressed: () => _mapController.move(center, 16),
            icon: Icon(Icons.my_location_rounded, size: 14.sp),
            label: Text('Vị trí ban đầu', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0), minimumSize: Size(0, 32.h)),
          ),
        ),
        if (!widget.isFullscreen)
          Positioned(
            top: 8.h,
            right: 8.w,
            child: Container(
              width: 32.w,
              height: 32.w,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20.sp,
                icon: Icon(Icons.fullscreen_rounded, color: colorScheme.onSurface),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: SafeArea(
                          child: Stack(
                            children: [
                              VehicleMapWidget(
                                vtracking: widget.vtracking,
                                stations: widget.stations,
                                isFullscreen: true,
                              ),
                              Positioned(
                                top: 16.h,
                                left: 16.w,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.shadow.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );

    if (widget.isFullscreen) {
      return mapStack;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250.h,
          child: mapStack,
        ),
      ],
    );
  }
}
