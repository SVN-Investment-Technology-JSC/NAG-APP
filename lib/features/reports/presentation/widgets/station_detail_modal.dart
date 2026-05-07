import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';

class StationDetailModal extends StatefulWidget {
  final ProductionTopStation station;
  final DateTime from;
  final DateTime to;
  final Set<int> tankerVehicleIds;

  const StationDetailModal({
    super.key,
    required this.station,
    required this.from,
    required this.to,
    required this.tankerVehicleIds,
  });

  @override
  State<StationDetailModal> createState() => _StationDetailModalState();
}

class _StationDetailModalState extends State<StationDetailModal> {
  final OrderService _orderService = OrderService(ApiClient.dio);
  bool _isLoading = true;
  List<OrderModel> _orders = [];

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
    return order.checkoutTimeStation ?? 
           order.orderMulti?.checkoutTimeStation ?? 
           order.orderEndDatetime;
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalLoadingMinutes = _orders.fold<int>(0, (sum, item) => sum + _getStationLoadingMinutes(item));
    final avgLoadingMinutes = _orders.isEmpty ? 0 : (totalLoadingMinutes / _orders.length).round();

    return Container(
      height: 0.9.sh,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0F766E), colorScheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết hiệu suất trạm',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            widget.station.stationName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    _buildStatItem('Số chuyến', _orders.length.toString()),
                    SizedBox(width: 12.w),
                    _buildStatItem('TG lấy hàng TB', '$avgLoadingMinutes phút'),
                    SizedBox(width: 12.w),
                    _buildStatItem('Tổng TG', '$totalLoadingMinutes phút'),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Text(
                          'Không có dữ liệu trong khoảng thời gian này',
                          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: _orders.length,
                        separatorBuilder: (context, index) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final order = _orders[index];
                          final loading = _getStationLoadingMinutes(order);
                          
                          return Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.vehicles?.vehicleLicensePlate ?? '-',
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Xe #${order.vehicles?.vehicleId}',
                                          style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    _buildStatusTag(order.orderStatus),
                                  ],
                                ),
                                Divider(height: 24.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildTimeCol('VÀO TRẠM', _getStationCheckInTime(order)),
                                    _buildTimeCol('RA TRẠM', _getStationCheckOutTime(order)),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'LẤY HÀNG',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '$loading phút',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF0F766E),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10.sp, fontWeight: FontWeight.bold),
            ),
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCol(String label, String? timeStr) {
    final time = timeStr != null ? DateTime.tryParse(timeStr)?.toLocal() : null;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          time != null ? DateFormat('HH:mm').format(time) : '--:--',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (time != null)
          Text(
            DateFormat('dd/MM').format(time),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 8.sp),
          ),
      ],
    );
  }

  Widget _buildStatusTag(String status) {
    Color color;
    String label;
    switch (status) {
      case 'completed':
        color = const Color(0xFF059669);
        label = 'Hoàn thành';
        break;
      case 'canceled':
        color = const Color(0xFFDC2626);
        label = 'Đã hủy';
        break;
      case 'running':
        color = const Color(0xFF2563EB);
        label = 'Đang chạy';
        break;
      case 'collecting':
        color = const Color(0xFF7C3AED);
        label = 'Nhận hàng';
        break;
      case 'transporting':
        color = const Color(0xFFD97706);
        label = 'Vận chuyển';
        break;
      case 'pending':
        color = const Color(0xFF64748B);
        label = 'Chờ xử lý';
        break;
      default:
        color = const Color(0xFF64748B);
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.w800),
      ),
    );
  }
}
