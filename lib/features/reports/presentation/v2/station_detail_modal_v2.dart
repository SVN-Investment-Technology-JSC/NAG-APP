import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';

/// "Chi tiết hiệu suất trạm" (v2). Loading, filtering, sorting and the loading-time maths are the same as v1;
/// only the presentation changed.
class StationDetailModalV2 extends StatefulWidget {
  final ProductionTopStation station;
  final DateTime from;
  final DateTime to;
  final Set<int> tankerVehicleIds;

  const StationDetailModalV2({
    super.key,
    required this.station,
    required this.from,
    required this.to,
    required this.tankerVehicleIds,
  });

  @override
  State<StationDetailModalV2> createState() => _StationDetailModalV2State();
}

class _StationDetailModalV2State extends State<StationDetailModalV2> {
  static const _perPage = 8;

  final OrderService _orderService = OrderService(ApiClient.dio);
  bool _isLoading = true;
  List<OrderModel> _orders = [];

  // presentation state
  bool _failed = false;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  String? _getStationCheckInTime(OrderModel order) {
    return order.checkinTimeStation ??
        order.orderMulti?.checkinTimeStation ??
        order.orderStartDatetime ??
        order.orderInitDatetime;
  }

  String? _getStationCheckOutTime(OrderModel order) {
    return order.checkoutTimeStation ?? order.orderMulti?.checkoutTimeStation ?? order.orderEndDatetime;
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _failed = false;
      _page = 0;
    });
    try {
      final List<String> dayRequests = [];
      DateTime cursor = widget.from;
      while (cursor.isBefore(widget.to) || cursor.isAtSameMomentAs(widget.to)) {
        dayRequests.add(DateFormat('yyyy-MM-dd').format(cursor));
        cursor = cursor.add(const Duration(days: 1));
      }

      final List<List<OrderModel>> results = await Future.wait(
        dayRequests.map((date) => _orderService.getOrdersByDate(date)),
      );

      final allOrders = results.expand((element) => element).toList();

      // Filter by station and tanker type
      final filtered = allOrders.where((order) {
        final stationId = order.stations?.stationId;
        if (stationId != widget.station.stationId) return false;

        // Must have check-in to be considered in performance
        if (_getStationCheckInTime(order) == null) return false;

        // Filter for tanker vehicles only (matching React logic)
        return widget.tankerVehicleIds.contains(order.vehicles?.vehicleId);
      }).toList();

      // Sort by time descending
      filtered.sort((a, b) {
        final timeAStr = _getStationCheckInTime(a) ?? a.orderInitDatetime;
        final timeBStr = _getStationCheckInTime(b) ?? b.orderInitDatetime;
        final timeA = DateTime.tryParse(timeAStr) ?? DateTime(1970);
        final timeB = DateTime.tryParse(timeBStr) ?? DateTime(1970);
        return timeB.compareTo(timeA);
      });

      if (mounted) {
        setState(() {
          _orders = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[StationDetailModal] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failed = true;
        });
      }
    }
  }

  int _getStationLoadingMinutes(OrderModel order) {
    final checkInStr = _getStationCheckInTime(order);
    final checkOutStr = _getStationCheckOutTime(order);

    if (checkInStr == null || checkOutStr == null) return 0;

    final checkIn = DateTime.tryParse(checkInStr);
    final checkOut = DateTime.tryParse(checkOutStr);

    if (checkIn == null || checkOut == null) return 0;
    if (checkOut.isBefore(checkIn)) return 0;

    return checkOut.difference(checkIn).inMinutes;
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);

    final totalLoadingMinutes = _orders.fold<int>(0, (sum, item) => sum + _getStationLoadingMinutes(item));
    final avgLoadingMinutes = _orders.isEmpty ? 0 : (totalLoadingMinutes / _orders.length).round();
    final df = DateFormat('dd/MM/yyyy');

    return Container(
      height: 0.9.sh,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 10.w, 14.h),
            decoration: BoxDecoration(
              color: t.card,
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2.r)),
                  ),
                ),
                Row(
                  children: [
                    const FxIconBadge(icon: Icons.local_gas_station_rounded, tone: FxTokens.emerald, size: 40),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chi tiết hiệu suất trạm', style: t.small),
                          SizedBox(height: 2.h),
                          Text(
                            widget.station.stationName,
                            style: t.h1.copyWith(fontSize: 18.sp),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '${df.format(widget.from)} – ${df.format(widget.to)}',
                            style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: t.text, size: 20.sp),
                      style: IconButton.styleFrom(backgroundColor: t.cardAlt, side: BorderSide(color: t.border)),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    _buildStatItem(t, Icons.local_shipping_outlined, FxTokens.blue, 'Số chuyến',
                        _isLoading ? '—' : _orders.length.toString(), null),
                    SizedBox(width: 8.w),
                    _buildStatItem(t, Icons.timer_outlined, FxTokens.emerald, 'TG lấy hàng TB',
                        _isLoading ? '—' : '$avgLoadingMinutes', 'phút'),
                    SizedBox(width: 8.w),
                    _buildStatItem(t, Icons.hourglass_bottom_rounded, FxTokens.amber, 'Tổng TG',
                        _isLoading ? '—' : '$totalLoadingMinutes', 'phút'),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent(t)),
        ],
      ),
    );
  }

  Widget _buildContent(FxTokens t) {
    if (_isLoading) {
      return ListView(
        padding: EdgeInsets.all(14.w),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 4; i++) ...[
            FxSkeleton(height: 118.h, radius: 14),
            SizedBox(height: 10.h),
          ],
        ],
      );
    }
    if (_failed) {
      return Center(
        child: FxEmpty(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu trạm',
          action: FilledButton.tonalIcon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: FxEmpty(
          icon: Icons.event_busy_rounded,
          title: 'Không có dữ liệu trong khoảng thời gian này',
        ),
      );
    }

    final page = fxPage(_orders, _page, _perPage);
    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 28.h),
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2.w, bottom: 10.h),
          child: Row(
            children: [
              Expanded(child: Text('DANH SÁCH CHUYẾN', style: t.overline)),
              Text('Mới nhất trước', style: t.tiny),
            ],
          ),
        ),
        for (final order in page) _buildOrderCard(t, order),
        FxPager(page: _page, total: _orders.length, size: _perPage, onChanged: (p) => setState(() => _page = p)),
      ],
    );
  }

  Widget _buildOrderCard(FxTokens t, OrderModel order) {
    final loading = _getStationLoadingMinutes(order);
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const FxIconBadge(icon: Icons.local_shipping_rounded, tone: FxTokens.blue, size: 34),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.vehicles?.vehicleLicensePlate ?? '-',
                      style: t.h3.copyWith(fontFeatures: FxTokens.tabular),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1.h),
                    Text('Xe #${order.vehicles?.vehicleId}', style: t.tiny),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              _buildStatusTag(order.orderStatus),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: t.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(child: _buildTimeCol(t, 'VÀO TRẠM', _getStationCheckInTime(order))),
                _vDivider(t),
                Expanded(child: _buildTimeCol(t, 'RA TRẠM', _getStationCheckOutTime(order))),
                _vDivider(t),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('LẤY HÀNG', style: t.overline),
                      SizedBox(height: 3.h),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '$loading', style: t.num(15.sp, color: t.ink(FxTokens.emerald))),
                          TextSpan(text: ' phút', style: t.tiny.copyWith(color: t.ink(FxTokens.emerald))),
                        ]),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider(FxTokens t) => Container(
        width: 1,
        height: 28.h,
        margin: EdgeInsets.symmetric(horizontal: 8.w),
        color: t.border,
      );

  Widget _buildStatItem(FxTokens t, IconData icon, Color tone, String label, String value, String? unit) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: t.cardAlt,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13.sp, color: t.ink(tone)),
                SizedBox(width: 4.w),
                Expanded(child: Text(label, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            SizedBox(height: 4.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: value, style: t.num(17.sp)),
                if (unit != null && value != '—') TextSpan(text: ' $unit', style: t.tiny),
              ])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCol(FxTokens t, String label, String? timeStr) {
    final time = timeStr != null ? DateTime.tryParse(timeStr)?.toLocal() : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.overline),
        SizedBox(height: 3.h),
        Text(
          time != null ? DateFormat('HH:mm').format(time) : '--:--',
          style: t.num(15.sp),
        ),
        if (time != null)
          Text(
            DateFormat('dd/MM').format(time),
            style: t.tiny.copyWith(fontSize: 9.5.sp, fontFeatures: FxTokens.tabular),
          ),
      ],
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = FxTokens.emerald;
        label = 'Hoàn thành';
        break;
      case 'canceled':
        color = FxTokens.red;
        label = 'Đã hủy';
        break;
      case 'running':
        color = FxTokens.blue;
        label = 'Đang chạy';
        break;
      case 'collecting':
        color = FxTokens.violet;
        label = 'Nhận hàng';
        break;
      case 'transporting':
        color = FxTokens.amber;
        label = 'Vận chuyển';
        break;
      case 'pending':
        color = FxTokens.slate;
        label = 'Chờ xử lý';
        break;
      default:
        color = FxTokens.slate;
        label = status;
    }

    return FxPill(label: label, tone: color, dot: true);
  }
}
