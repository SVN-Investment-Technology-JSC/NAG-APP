import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:vehicle_management/core/theme/app_colors.dart';
import 'package:vehicle_management/core/theme/app_spacing.dart';
import 'package:vehicle_management/features/order/data/models/order_model.dart';
import 'package:vehicle_management/features/vehicle/data/models/vehicle_model.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class HomeOrderItem extends StatelessWidget {
  final OrderModel order;
  final int orderNumber;
  final List<VehicleModel> vehicles;

  const HomeOrderItem({
    super.key,
    required this.order,
    required this.orderNumber,
    required this.vehicles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final status = _resolveStatus(colorScheme, l10n, theme);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.r),
        border: order.orderStatus == 'collecting'
            ? Border.all(
                color: status.color.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          _AccentBar(color: status.color),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: AppSpacing.smH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StnRow(orderNumber: orderNumber, status: status),
                  SizedBox(height: AppSpacing.xsH),
                  _PlateRow(label: _vehicleLabel),
                  SizedBox(height: AppSpacing.xsH),
                  _MetaRow(order: order, status: status),
                  if (order.orderStatus == 'completed') _DistanceRow(order: order),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _vehicleLabel {
    final plate = order.vehicles?.vehicleLicensePlate ?? '---';
    final vehicleName = vehicles
        .where((v) => v.vehicleId == order.vehicles?.vehicleId)
        .map((v) => v.vehicleName)
        .firstOrNull;
    if (vehicleName != null && vehicleName.isNotEmpty) {
      return '$plate | $vehicleName';
    }
    return plate;
  }

  _OrderStatus _resolveStatus(
      ColorScheme colorScheme, AppLocalizations l10n, ThemeData theme) {
    final ext = theme.extension<AppColorsExtension>()!;
    switch (order.orderStatus) {
      case 'completed':
        return _OrderStatus(colorScheme.tertiary, l10n.completedStatus);
      case 'collecting':
        return _OrderStatus(ext.warning, l10n.collecting);
      case 'init':
        return _OrderStatus(colorScheme.outline, l10n.initStatus);
      default:
        return _OrderStatus(colorScheme.primary, l10n.pendingOrders);
    }
  }
}

class _OrderStatus {
  final Color color;
  final String text;
  const _OrderStatus(this.color, this.text);
}

class _AccentBar extends StatelessWidget {
  final Color color;
  const _AccentBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4.w,
      height: 64.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.r),
          bottomLeft: Radius.circular(12.r),
        ),
      ),
    );
  }
}

class _StnRow extends StatelessWidget {
  final int orderNumber;
  final _OrderStatus status;

  const _StnRow({required this.orderNumber, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          '#$orderNumber',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: status.color,
            fontSize: 14.sp,
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: status.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            status.text,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: status.color,
              fontSize: 9.sp,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlateRow extends StatelessWidget {
  final String label;

  const _PlateRow({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w800,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MetaRow extends StatelessWidget {
  final OrderModel order;
  final _OrderStatus status;

  const _MetaRow({
    required this.order,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final duration = _computeDuration();
    final endTime = _computeEndTime();
    final initTime = _computeInitTime();

    return Row(
      children: [
        if (initTime != null) ...[
          Icon(Icons.access_time_rounded, size: 11.sp, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 2.w),
          Text(
            initTime,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              fontSize: 10.sp,
            ),
          ),
        ],
        if (duration != null) ...[
          SizedBox(width: AppSpacing.sm),
          Icon(Icons.schedule_rounded, size: 11.sp, color: status.color),
          SizedBox(width: 2.w),
          Text(
            duration,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: status.color,
              fontSize: 10.sp,
            ),
          ),
        ],
        if (endTime != null) ...[
          SizedBox(width: AppSpacing.sm),
          Text(
            endTime,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10.sp,
            ),
          ),
        ],
      ],
    );
  }

  String? _computeInitTime() {
    final initDt = DateTime.tryParse(order.orderInitDatetime);
    if (initDt == null) return null;
    final local = initDt.toLocal();
    return '${local.hour} giờ ${local.minute.toString().padLeft(2, '0')} phút';
  }

  String? _computeDuration() {
    if (order.orderStartDatetime == null || order.orderEndDatetime == null) {
      return null;
    }
    final start = DateTime.tryParse(order.orderStartDatetime!);
    final end = DateTime.tryParse(order.orderEndDatetime!);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return hours > 0
        ? '${hours}h${mins.toString().padLeft(2, '0')}m'
        : '${mins}m';
  }

  String? _computeEndTime() {
    if (order.orderEndDatetime == null) return null;
    final end = DateTime.tryParse(order.orderEndDatetime!);
    if (end == null) return null;
    return DateFormat('HH:mm').format(end.toLocal());
  }
}

class _DistanceRow extends StatelessWidget {
  final OrderModel order;
  const _DistanceRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final multi = order.orderMulti;
    if (multi == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(top: 3.h),
      child: Row(
        children: [
          Icon(Icons.straighten_rounded,
              size: 11.sp, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 3.w),
          Text(
            '${multi.distanceKm.toStringAsFixed(1)} km',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Icon(Icons.pause_circle_outline_rounded,
              size: 11.sp, color: colorScheme.onSurfaceVariant),
          SizedBox(width: 3.w),
          Text(
            '${multi.stopCount} ${l10n.stopCountLabel}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }
}
