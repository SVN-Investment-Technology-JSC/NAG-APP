import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// v2 of `VehicleTripsPanel`: same constructor, same sorting / texts, new layout.
/// [colorScheme] and [isDark] are kept for API compatibility; colours come from [FxTokens].
class VehicleTripsPanelV2 extends StatelessWidget {
  final List<OrderModel> completedOrders;
  final List<OrderModel> activeOrders;
  final VehicleModel selectedVehicle;
  final ColorScheme colorScheme;
  final bool isDark;
  final AppLocalizations l10n;

  const VehicleTripsPanelV2({
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
    final t = FxTokens.of(context);
    final allTrips = [...activeOrders, ...completedOrders];
    allTrips.sort((a, b) {
      final aTime = DateTime.tryParse(a.updatedAt ?? '') ?? DateTime(2000);
      final bTime = DateTime.tryParse(b.updatedAt ?? '') ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return FxCard(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(t),
          Divider(height: 1, color: t.divider),
          if (allTrips.isEmpty)
            FxEmpty(icon: Icons.inbox_rounded, title: l10n.noTripsForVehicle)
          else
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 0),
              child: Column(children: [for (final order in allTrips) _buildTripCard(t, order)]),
            ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildHeader(FxTokens t) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          FxIconBadge(icon: Icons.local_shipping_rounded, tone: FxTokens.emerald, size: 32),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              selectedVehicle.vehicleLicensePlate,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.h2.copyWith(fontFeatures: FxTokens.tabular),
            ),
          ),
          if (activeOrders.isNotEmpty) ...[
            Flexible(
              child: FxPill(label: '${activeOrders.length} ${l10n.activeTrips}', tone: FxTokens.cyan, dot: true),
            ),
            SizedBox(width: 6.w),
          ],
          Flexible(
            child: FxPill(label: '${completedOrders.length} ${l10n.completedTrips}', tone: FxTokens.emerald, dot: true),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(FxTokens t, OrderModel order) {
    final isCompleted = order.orderStatus == 'completed';
    final accentColor = isCompleted ? FxTokens.emerald : FxTokens.cyan;

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
        durationText = hours > 0 ? '${hours}h${mins.toString().padLeft(2, '0')}m' : '${mins}m';
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
      margin: EdgeInsets.only(bottom: 8.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: t.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(width: 4.w, color: accentColor),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Vehicle + status
                    Row(
                      children: [
                        Icon(Icons.local_shipping_rounded, size: 14.sp, color: t.ink(accentColor)),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            _buildVehicleLabel(order),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.h3.copyWith(fontSize: 12.5.sp, fontFeatures: FxTokens.tabular),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        FxPill(label: statusText, tone: accentColor),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    // Row 2: Station + duration + end time
                    Row(
                      children: [
                        Icon(Icons.factory_outlined, size: 12.sp, color: t.textFaint),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            order.stations?.stationName ?? '---',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.tiny.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (durationText != null) ...[
                          Icon(Icons.schedule_rounded, size: 12.sp, color: t.ink(accentColor)),
                          SizedBox(width: 3.w),
                          Flexible(
                            child: Text(
                              durationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: t.ink(accentColor),
                                fontFeatures: FxTokens.tabular,
                              ),
                            ),
                          ),
                        ],
                        if (endTimeText != null) ...[
                          SizedBox(width: 10.w),
                          Text(
                            endTimeText,
                            style: t.tiny.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
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
