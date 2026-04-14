import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:vehicle_management/features/order/data/models/order_model.dart';
import 'package:vehicle_management/features/vehicle/data/models/vehicle_model.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class VehicleTripsPanel extends StatelessWidget {
  final List<OrderModel> completedOrders;
  final List<OrderModel> activeOrders;
  final VehicleModel selectedVehicle;
  final ColorScheme colorScheme;
  final bool isDark;
  final AppLocalizations l10n;

  const VehicleTripsPanel({
    super.key,
    required this.completedOrders,
    required this.activeOrders,
    required this.selectedVehicle,
    required this.colorScheme,
    required this.isDark,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final allTrips = [...activeOrders, ...completedOrders];
    allTrips.sort((a, b) {
      final aTime = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          // Divider
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
          // Trip list or empty state
          if (allTrips.isEmpty)
            _buildEmptyState()
          else
            ...allTrips.map((order) => _buildTripCard(order)),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_rounded,
            size: 18.sp,
            color: const Color(0xFF10B981),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              selectedVehicle.vehicleLicensePlate,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (activeOrders.isNotEmpty)
            Container(
              margin: EdgeInsets.only(right: 6.w),
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${activeOrders.length} ${l10n.activeTrips}',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0EA5E9),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '${completedOrders.length} ${l10n.completedTrips}',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 40.sp,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            SizedBox(height: 8.h),
            Text(
              l10n.noTripsForVehicle,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripCard(OrderModel order) {
    final isCompleted = order.orderStatus == 'completed';
    final accentColor =
        isCompleted ? const Color(0xFF10B981) : const Color(0xFF0EA5E9);

    String statusText;
    if (isCompleted) {
      statusText = l10n.completedStatus;
    } else if (order.orderStatus == 'collecting') {
      statusText = l10n.collecting;
    } else {
      statusText = l10n.activeTrips;
    }

    // Duration calculation
    String? durationText;
    if (order.orderStartDatetime != null && order.orderEndDatetime != null) {
      final start = DateTime.tryParse(order.orderStartDatetime!);
      final end = DateTime.tryParse(order.orderEndDatetime!);
      if (start != null && end != null) {
        final diff = end.difference(start);
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        durationText =
            hours > 0 ? '${hours}h${mins.toString().padLeft(2, '0')}m' : '${mins}m';
      }
    }

    // End time
    String? endTimeText;
    if (order.orderEndDatetime != null) {
      final end = DateTime.tryParse(order.orderEndDatetime!);
      if (end != null) {
        endTimeText = DateFormat('HH:mm').format(end);
      }
    }

    return Container(
      margin: EdgeInsets.fromLTRB(10.w, 4.h, 10.w, 4.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 4.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                bottomLeft: Radius.circular(10.r),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Vehicle + status
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping_rounded,
                        size: 14.sp,
                        color: accentColor,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          _buildVehicleLabel(order),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  // Row 2: Station + duration + end time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.stations?.stationName ?? '---',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (durationText != null) ...[
                        Icon(
                          Icons.schedule_rounded,
                          size: 12.sp,
                          color: accentColor,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          durationText,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                      if (endTimeText != null) ...[
                        SizedBox(width: 10.w),
                        Text(
                          endTimeText,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildVehicleLabel(OrderModel order) {
    final plate = order.vehicles?.vehicleLicensePlate;
    if (plate == null || plate.isEmpty) return '#${order.orderId}';
    if (selectedVehicle.vehicleName.isNotEmpty) {
      return '$plate | ${selectedVehicle.vehicleName}';
    }
    return plate;
  }
}
