import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/network/notification_socket_service.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/v2/widgets/fleet_alert_bell.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/user_manage/data/services/user_manage_service.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/features/vehicle/presentation/v2/vehicle_map_widget_v2.dart';
import 'package:nguyenanh/features/vehicle/presentation/v2/vx_widgets.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

typedef _StatusOption = ({String value, String label, IconData icon, Color tone});

/// "Chuyến đi" tab (v2). Same constructor, state, permissions, API calls, dialogs and sheets as
/// `VehicleManagementPage`; only the widget tree is redesigned.
class VehicleManagementPageV2 extends StatefulWidget {
  final List<OrderModel> pendingOrders;
  final List<VehicleModel> vehicles;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<Station> stations;
  final DateTime? initialDate;
  final VoidCallback? onRefresh;
  final NotificationSocketService notificationService;

  const VehicleManagementPageV2({
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
  State<VehicleManagementPageV2> createState() => _VehicleManagementPageV2State();
}

class _VehicleManagementPageV2State extends State<VehicleManagementPageV2> with SingleTickerProviderStateMixin {
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
  bool _limitTo3 = false;
  bool _canViewLotOrder = false;
  bool _canViewDailyTrips = false;
  FleetPermissions _fleetPerms = const FleetPermissions();
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
  void didUpdateWidget(covariant VehicleManagementPageV2 oldWidget) {
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

  // ── Data & logic (verbatim from VehicleManagementPage) ────────────────────

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
          _limitTo3 = _userRole != 'admin' && myPerms.contains('/dashboard__view_lot_order_limit_3');
          _canViewLotOrder = _userRole == 'admin' ||
              myPerms.contains('/dashboard__view_lot_order') ||
              myPerms.contains('/dashboard__view_lot_order_limit_3');
          _canViewDailyTrips = _userRole == 'admin' || myPerms.contains('/dashboard__view_trips');
          _fleetPerms = FleetPermissions.fromList(_userRole, myPerms);
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
          .where((o) =>
              o.vehicles != null && allowedStatuses.contains(o.orderStatus) && mixerIds.contains(o.vehicles!.vehicleId))
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
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    final sortedOrders = List<OrderModel>.from(_orders)..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

    for (var i = 0; i < sortedOrders.length; i++) {
      final order = sortedOrders[i];
      final row = i + 1;

      final vehicle = widget.vehicles.where((v) => v.vehicleId == order.vehicles?.vehicleId).firstOrNull;

      String durationText = '';
      if (order.orderStartDatetime != null && order.orderEndDatetime != null) {
        final start = DateTime.tryParse(order.orderStartDatetime!);
        final end = DateTime.tryParse(order.orderEndDatetime!);
        if (start != null && end != null) {
          final diff = end.difference(start);
          final hours = diff.inHours;
          final mins = diff.inMinutes % 60;
          durationText = hours > 0 ? '${hours}h${mins.toString().padLeft(2, '0')}m' : '${mins}m';
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
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value = values[col];
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
          (v) => v!.vehicleName == vehicle.vehicleName || v.licensePlate == vehicle.vehicleLicensePlate,
          orElse: () => null,
        );
  }

  // ── Vehicle sheet ─────────────────────────────────────────────────────────

  void _showVehiclePopup(VehicleModel vehicle) {
    if (!_canOrderDetail && _userRole != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không có quyền xem chi tiết các chuyến xe (đơn hàng)'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: FxTokens.red,
        ),
      );
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final vtracking = _findVtracking(vehicle);
    final vehicleOrders = _ordersForVehicle(vehicle.vehicleId);

    final sortedOrders = List<OrderModel>.from(vehicleOrders)
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

    final List<_StatusOption> statusOptions = [
      (value: 'available', label: l10n.statusAvailable, icon: Icons.check_circle_outline_rounded, tone: FxTokens.emerald),
      (value: 'incident', label: l10n.statusIncident, icon: Icons.warning_amber_rounded, tone: FxTokens.red),
      (value: 'maintenance', label: l10n.statusMaintenance, icon: Icons.construction_rounded, tone: FxTokens.amber),
      (value: 'other', label: l10n.statusOther, icon: Icons.help_outline_rounded, tone: FxTokens.violet),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FxTokens.of(context).card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        String baselineStatus = vehicle.vehicleStatus;
        bool isUpdating = false;

        return StatefulBuilder(
          builder: (context, setStatePopup) {
            final t = FxTokens.of(context);

            void showStatusSelectorDialog({
              required BuildContext context,
              required String currentStatus,
              required List<_StatusOption> statusOptions,
              required AppLocalizations l10n,
              required Function(String) onSave,
            }) {
              showDialog(
                context: context,
                builder: (dialogCtx) {
                  String tempSelectedStatus = currentStatus;
                  final t = FxTokens.of(dialogCtx);
                  return AlertDialog(
                    backgroundColor: t.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22.r),
                    ),
                    titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
                    contentPadding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 4.h),
                    title: Row(
                      children: [
                        FxIconBadge(icon: Icons.tune_rounded, tone: FxTokens.blue, size: 34),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            l10n.confirmChangeStatus,
                            style: t.h2.copyWith(fontSize: 16.sp),
                          ),
                        ),
                      ],
                    ),
                    content: StatefulBuilder(
                      builder: (context, setStateDialog) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: statusOptions.map((opt) {
                            final isSelected = tempSelectedStatus == opt.value;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 8.h),
                              child: Material(
                                color: isSelected ? t.soft(opt.tone) : Colors.transparent,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                  side: BorderSide(
                                    color: isSelected ? opt.tone.withValues(alpha: 0.6) : t.border,
                                    width: 1.4,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setStateDialog(() {
                                      tempSelectedStatus = opt.value;
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                    child: Row(
                                      children: [
                                        FxIconBadge(icon: opt.icon, tone: isSelected ? opt.tone : FxTokens.slate, size: 30),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Text(
                                            opt.label,
                                            style: TextStyle(
                                              fontSize: 13.5.sp,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? t.ink(opt.tone) : t.text,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                          color: isSelected ? t.ink(opt.tone) : t.textFaint,
                                          size: 20.sp,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    actionsPadding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: TextButton.styleFrom(foregroundColor: t.textMuted),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          onSave(tempSelectedStatus);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: FxTokens.blue,
                          foregroundColor: Colors.white,
                          minimumSize: Size(96.w, 44.h),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ],
                  );
                },
              );
            }

            _StatusOption optionOf(String statusVal) => statusOptions.firstWhere(
                  (o) => o.value == statusVal,
                  orElse: () => statusOptions[0],
                );

            final current = optionOf(baselineStatus);

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 8.h),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: t.border,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Header
                      Row(
                        children: [
                          FxIconBadge(icon: Icons.local_shipping_rounded, tone: FxTokens.blue, size: 46),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        vehicle.vehicleLicensePlate,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.h1.copyWith(fontSize: 19.sp, fontFeatures: FxTokens.tabular),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    FxPill(label: current.label, tone: current.tone, dot: true),
                                  ],
                                ),
                                if (vehicle.vehicleName.isNotEmpty && vehicle.vehicleName != vehicle.vehicleLicensePlate) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    vehicle.vehicleName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.small,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      // Current status card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14.w),
                        decoration: BoxDecoration(
                          color: t.cardAlt,
                          borderRadius: BorderRadius.circular(FxTokens.rCard),
                          border: Border.all(color: t.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FxIconBadge(icon: current.icon, tone: current.tone, size: 40),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('TRẠNG THÁI XE', style: t.overline),
                                      SizedBox(height: 3.h),
                                      Text(
                                        current.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.h2.copyWith(color: t.ink(current.tone)),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                FilledButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () => showStatusSelectorDialog(
                                            context: context,
                                            currentStatus: baselineStatus,
                                            statusOptions: statusOptions,
                                            l10n: l10n,
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
                                                        backgroundColor: FxTokens.green,
                                                      ),
                                                    );
                                                  }
                                                  widget.onRefresh?.call();
                                                } else {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(l10n.updateStatusFailed),
                                                        backgroundColor: FxTokens.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(l10n.updateStatusFailed),
                                                      backgroundColor: FxTokens.red,
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
                                    backgroundColor: FxTokens.blue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: FxTokens.blue.withValues(alpha: 0.5),
                                    minimumSize: Size(0, 40.h),
                                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isUpdating
                                      ? SizedBox(
                                          width: 16.w,
                                          height: 16.w,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded, size: 14.sp),
                                            SizedBox(width: 6.w),
                                            Text(
                                              'Cập nhật',
                                              style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w800),
                                            ),
                                          ],
                                        ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            // Info hint
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: t.soft(FxTokens.blue),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 15.sp, color: t.ink(FxTokens.blue)),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Nhấn vào nút Cập nhật để thay đổi trạng thái xe hoặc báo cáo sự cố.',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: t.ink(FxTokens.blue),
                                        fontWeight: FontWeight.w500,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                      // Scrollable body
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            if (vtracking != null && vtracking.hasPosition) ...[
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(FxTokens.rCard),
                                  border: Border.all(color: t.border),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(FxTokens.rCard),
                                  child: VehicleMapWidgetV2(
                                    vtracking: vtracking,
                                    stations: widget.stations,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],
                            FxSectionHeader(
                              icon: Icons.route_rounded,
                              title: l10n.tripsOnDate,
                              subtitle: DateFormat('dd/MM/yyyy').format(_selectedDate),
                              tone: FxTokens.blue,
                              trailing: FxPill(
                                label: '${vehicleOrders.length}',
                                tone: vehicleOrders.isEmpty ? FxTokens.slate : FxTokens.blue,
                                solid: vehicleOrders.isNotEmpty,
                              ),
                            ),
                            if (sortedOrders.isEmpty)
                              FxEmpty(icon: Icons.event_busy_rounded, title: l10n.noTripsForVehicle)
                            else
                              for (var i = 0; i < sortedOrders.length; i++)
                                VxTripTimelineItem(order: sortedOrders[i], isLast: i == sortedOrders.length - 1),
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

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    final showLotOrder = _canViewLotOrder;
    final showDailyTrips = _canViewDailyTrips;

    PreferredSizeWidget? bottomTabBar;
    Widget bodyWidget;

    if (showLotOrder && showDailyTrips) {
      bottomTabBar = _buildTabBar(t, l10n);
      bodyWidget = TabBarView(
        children: [
          _buildQueueTab(l10n, t),
          _buildDailyTripsTab(l10n, t),
        ],
      );
    } else if (showLotOrder) {
      bottomTabBar = null;
      bodyWidget = _buildQueueTab(l10n, t);
    } else if (showDailyTrips) {
      bottomTabBar = null;
      bodyWidget = _buildDailyTripsTab(l10n, t);
    } else {
      // Fallback before permissions are loaded, or if none are active
      bottomTabBar = _buildTabBar(t, l10n);
      bodyWidget = TabBarView(
        children: [
          _buildQueueTab(l10n, t),
          _buildDailyTripsTab(l10n, t),
        ],
      );
    }

    // Same tab count as v1; the controller length follows the number of tabs actually shown.
    final int controllerLength = bottomTabBar != null ? 2 : 1;

    return DefaultTabController(
      length: controllerLength,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.bg,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 16.w,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.tripManagement,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.h1.copyWith(fontSize: 19.sp),
              ),
              SizedBox(height: 1.h),
              Text(
                MaterialLocalizations.of(context).formatFullDate(_selectedDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.tiny,
              ),
            ],
          ),
          bottom: bottomTabBar,
          actions: [
            Center(child: _dateChip(t, l10n, isToday)),
            SizedBox(width: 2.w),
            IconButton(
              onPressed: _orders.isEmpty ? null : _exportExcel,
              icon: Icon(
                Icons.table_chart_outlined,
                size: 20.sp,
                color: _orders.isEmpty ? t.textFaint : t.ink(FxTokens.emerald),
              ),
              tooltip: 'Export Excel',
            ),
            // fleet-monitoring alerts (old general notifications are not shown in the new UI)
            if (_fleetPerms.any) FleetAlertBell(perms: _fleetPerms),
            SizedBox(width: 6.w),
          ],
        ),
        body: bodyWidget,
      ),
    );
  }

  Widget _dateChip(FxTokens t, AppLocalizations l10n, bool isToday) {
    return Material(
      color: t.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: t.border),
      ),
      child: InkWell(
        onTap: _pickDate,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 7.h, 6.w, 7.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 14.sp, color: t.ink(FxTokens.blue)),
              SizedBox(width: 6.w),
              Text(
                isToday ? l10n.today : DateFormat('dd/MM').format(_selectedDate),
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                  fontFeatures: FxTokens.tabular,
                ),
              ),
              SizedBox(width: 2.w),
              Icon(Icons.expand_more_rounded, size: 16.sp, color: t.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTabBar(FxTokens t, AppLocalizations l10n) {
    final tabs = <({IconData icon, String label})>[
      (icon: Icons.format_list_numbered_rounded, label: l10n.vehicleQueue),
      (icon: Icons.route_rounded, label: l10n.dailyTrips),
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
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tb.icon, size: 15.sp),
                        SizedBox(width: 5.w),
                        Flexible(child: Text(tb.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Queue (lot order) tab ─────────────────────────────────────────────────

  Widget _buildQueueTab(AppLocalizations l10n, FxTokens t) {
    var sorted = List<OrderModel>.from(widget.pendingOrders)..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    if (_limitTo3 && sorted.length > 3) {
      sorted = sorted.sublist(0, 3);
    }

    return Stack(
      children: [
        Column(
          children: [
            if (sorted.isNotEmpty) _buildQueueHeader(l10n, t, sorted.length),
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 14.w),
                        child: FxEmpty(icon: Icons.inbox_rounded, title: l10n.noPendingOrders),
                      ),
                    )
                  : (_isManualMode
                      ? ReorderableListView.builder(
                          padding: EdgeInsets.only(top: 2.h, bottom: 24.h),
                          itemCount: sorted.length,
                          proxyDecorator: (child, index, animation) => AnimatedBuilder(
                            animation: animation,
                            builder: (context, child) {
                              final v = Curves.easeOut.transform(animation.value);
                              return Transform.scale(
                                scale: 1 + 0.02 * v,
                                child: Material(type: MaterialType.transparency, child: child),
                              );
                            },
                            child: child,
                          ),
                          onReorder: (oldIndex, newIndex) async {
                            if (oldIndex < newIndex) newIndex -= 1;
                            if (oldIndex == newIndex) return;

                            final order = sorted[oldIndex];
                            final targetOrderNumber = newIndex + 1;

                            setState(() => _isReordering = true);
                            try {
                              await _orderService.updateOrderNumber(order.orderId, targetOrderNumber);
                              // Refresh comes from the main shell / socket updating pendingOrders (same as v1).
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
                                child: VxQueueOrderCard(
                                  order: sorted[index],
                                  orderNumber: index + 1,
                                  vehicles: widget.vehicles,
                                  manual: true,
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(top: 2.h, bottom: 24.h),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            return VxQueueOrderCard(
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
              color: t.bg.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: t.card,
                  borderRadius: BorderRadius.circular(FxTokens.rTile),
                  border: Border.all(color: t.border),
                  boxShadow: t.shadow,
                ),
                child: SizedBox(
                  width: 26.w,
                  height: 26.w,
                  child: const CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQueueHeader(AppLocalizations l10n, FxTokens t, int count) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 800.w),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FxIconBadge(icon: Icons.format_list_numbered_rounded, tone: FxTokens.blue, size: 36),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.vehicleQueue, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.h2),
                        SizedBox(height: 1.h),
                        Text(
                          _isManualMode ? 'Giữ và kéo để đổi vị trí · chạm để nhập số thứ tự' : '$count xe · theo số thứ tự lốt',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                        ),
                      ],
                    ),
                  ),
                  if (_canManualSort && widget.onRefresh != null) ...[
                    SizedBox(width: 8.w),
                    RotationTransition(
                      turns: _reloadAnimController,
                      child: FxMapButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Tải lại',
                        onTap: () {
                          if (widget.onRefresh != null) widget.onRefresh!();
                          _reloadAnimController.forward(from: 0.0);
                        },
                      ),
                    ),
                  ],
                ],
              ),
              if (_canManualSort) ...[
                SizedBox(height: 12.h),
                FxSegmented<bool>(
                  dense: true,
                  segments: const [
                    FxSegment(false, 'AUTO', icon: Icons.auto_mode_rounded),
                    FxSegment(true, 'MANUAL', icon: Icons.pan_tool_alt_outlined),
                  ],
                  value: _isManualMode,
                  onChanged: (v) => setState(() => _isManualMode = v),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditOrderNumberDialog(OrderModel order, int currentNumber) {
    final TextEditingController controller = TextEditingController(text: currentNumber.toString());
    showDialog(
      context: context,
      builder: (dialogContext) {
        final t = FxTokens.of(dialogContext);
        return AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)),
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
          contentPadding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
          title: Row(
            children: [
              FxIconBadge(icon: Icons.swap_vert_rounded, tone: FxTokens.blue, size: 34),
              SizedBox(width: 10.w),
              Expanded(child: Text('Đổi thứ tự lốt xe', style: t.h2.copyWith(fontSize: 16.sp))),
            ],
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: t.body.copyWith(fontWeight: FontWeight.w700, fontFeatures: FxTokens.tabular),
            decoration: InputDecoration(
              labelText: 'Nhập số thứ tự mới',
              prefixIcon: Icon(Icons.tag_rounded, size: 18.sp),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: t.textMuted),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FxTokens.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(96.w, 44.h),
              ),
              onPressed: () async {
                final newNumber = int.tryParse(controller.text);
                if (newNumber != null && newNumber != currentNumber) {
                  Navigator.pop(dialogContext);
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
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  // ── Daily trips tab ───────────────────────────────────────────────────────

  Widget _buildDailyTripsTab(AppLocalizations l10n, FxTokens t) {
    if (_isLoading) {
      return _buildDailyTripsSkeleton();
    }

    if (widget.vehicles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: FxEmpty(icon: Icons.local_shipping_outlined, title: l10n.noVehicles),
        ),
      );
    }

    final sortedVehicles = _sortedVehicles;
    final totalAll = sortedVehicles.length;
    final totalMixers = sortedVehicles.where((v) => v.vehicleName.toUpperCase().startsWith('X')).length;
    final totalOthers = sortedVehicles.where((v) => !v.vehicleName.toUpperCase().startsWith('X')).length;

    final query = _searchQuery.trim().toLowerCase();
    final filteredVehicles = sortedVehicles.where((v) {
      final isMixer = v.vehicleName.toUpperCase().startsWith('X');
      if (_categoryFilter == 'mixer' && !isMixer) return false;
      if (_categoryFilter == 'other' && isMixer) return false;

      if (query.isEmpty) return true;
      return v.vehicleLicensePlate.toLowerCase().contains(query) || v.vehicleName.toLowerCase().contains(query);
    }).toList();

    // Summary figures: the sum of the per-vehicle trip counts the list already shows.
    final tripCounts = [for (final v in sortedVehicles) _ordersForVehicle(v.vehicleId).length];
    final totalTrips = tripCounts.fold<int>(0, (a, b) => a + b);
    final withTrips = tripCounts.where((n) => n > 0).length;

    final header = <Widget>[
      _buildDailySummary(t, l10n, totalTrips, withTrips, totalAll),
      SizedBox(height: 12.h),
      FxSearchField(
        controller: _searchController,
        hint: l10n.searchVehicleHint,
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
      SizedBox(height: 10.h),
      FxSegmented<String>(
        dense: true,
        segments: [
          FxSegment('all', '${l10n.allFilter} · $totalAll'),
          FxSegment('mixer', '${l10n.mixerFilter} · $totalMixers'),
          FxSegment('other', '${l10n.otherFilter} · $totalOthers'),
        ],
        value: _categoryFilter,
        onChanged: (v) => setState(() => _categoryFilter = v),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 8.h),
        child: Row(
          children: [
            Text('DANH SÁCH XE · ${filteredVehicles.length}', style: t.overline.copyWith(fontFeatures: FxTokens.tabular)),
            const Spacer(),
            Icon(Icons.sort_rounded, size: 13.sp, color: t.textFaint),
            SizedBox(width: 4.w),
            Text('Mới hoạt động trước', style: t.tiny.copyWith(color: t.textFaint)),
          ],
        ),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
        itemCount: header.length + (filteredVehicles.isEmpty ? 1 : filteredVehicles.length),
        itemBuilder: (context, i) {
          if (i < header.length) {
            return Center(
              child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 800.w), child: header[i]),
            );
          }
          if (filteredVehicles.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(top: 24.h),
              child: FxEmpty(icon: Icons.search_off_rounded, title: l10n.noResultsFound),
            );
          }
          final vehicle = filteredVehicles[i - header.length];
          return VxVehicleTile(
            vehicle: vehicle,
            index: sortedVehicles.indexOf(vehicle),
            tripCount: _ordersForVehicle(vehicle.vehicleId).length,
            onTap: () => _showVehiclePopup(vehicle),
          );
        },
      ),
    );
  }

  Widget _buildDailySummary(FxTokens t, AppLocalizations l10n, int totalTrips, int withTrips, int totalVehicles) {
    final idle = totalVehicles - withTrips;
    final pct = totalVehicles == 0 ? 0 : (withTrips / totalVehicles * 100).round();

    Widget mini(IconData icon, String label, int value) => Expanded(
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 14.sp, color: Colors.white.withValues(alpha: 0.85)),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5.sp, color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text('$value', style: t.num(20.sp, color: Colors.white)),
              ],
            ),
          ),
        );

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FxTokens.rCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
        ),
        boxShadow: t.dark ? const [] : [BoxShadow(color: FxTokens.blue.withValues(alpha: 0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, size: 15.sp, color: Colors.white.withValues(alpha: 0.85)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  '${l10n.dailyTrips} · ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontFeatures: FxTokens.tabular,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$totalTrips', style: t.num(38.sp, color: Colors.white)),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(bottom: 5.h),
                child: Text(
                  l10n.trips,
                  style: TextStyle(fontSize: 13.sp, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          FxStackBar(
            height: 6,
            parts: [
              (value: withTrips.toDouble(), color: const Color(0xFF6EE7B7)),
              (value: idle.toDouble(), color: Colors.white.withValues(alpha: 0.18)),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '$withTrips/$totalVehicles xe đã có chuyến · $pct%',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.8),
              fontFeatures: FxTokens.tabular,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              mini(Icons.local_shipping_rounded, 'Xe có chuyến', withTrips),
              SizedBox(width: 8.w),
              mini(Icons.hourglass_empty_rounded, l10n.noTripsYet, idle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTripsSkeleton() {
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FxSkeleton(height: 190.h, radius: 18),
        SizedBox(height: 12.h),
        FxSkeleton(height: 42.h),
        SizedBox(height: 10.h),
        FxSkeleton(height: 34.h),
        SizedBox(height: 20.h),
        for (var i = 0; i < 6; i++) ...[
          FxSkeleton(height: 64.h, radius: 14),
          SizedBox(height: 8.h),
        ],
      ],
    );
  }
}
