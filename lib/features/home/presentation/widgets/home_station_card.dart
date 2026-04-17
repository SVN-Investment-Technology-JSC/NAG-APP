import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:vehicle_management/core/theme/app_colors.dart';
import 'package:vehicle_management/core/theme/app_spacing.dart';
import 'package:vehicle_management/features/order/data/models/order_model.dart';
import 'package:vehicle_management/features/stations/data/models/station_model.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class HomeStationCard extends StatelessWidget {
  final Station station;
  final List<OrderModel> collectingVehicles;
  final bool isCameraConnected;

  const HomeStationCard({
    super.key,
    required this.station,
    required this.collectingVehicles,
    required this.isCameraConnected,
  });

  bool get _hasCollecting => collectingVehicles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xsH),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14.r),
        border: _hasCollecting
            ? Border.all(
                color: colorScheme.tertiary.withValues(alpha: 0.3),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StationHeader(
            stationName: station.stationName,
            hasCollecting: _hasCollecting,
            isCameraConnected: isCameraConnected,
            collectingCount: collectingVehicles.length,
            collectingLabel: l10n.collecting,
          ),
          if (_hasCollecting)
            _CollectingList(
              collectingVehicles: collectingVehicles,
              collectingLabel: l10n.collecting,
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, AppSpacing.smH, 14.w, 12.h),
              child: Text(
                '---',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StationHeader extends StatelessWidget {
  final String stationName;
  final bool hasCollecting;
  final bool isCameraConnected;
  final int collectingCount;
  final String collectingLabel;

  const _StationHeader({
    required this.stationName,
    required this.hasCollecting,
    required this.isCameraConnected,
    required this.collectingCount,
    required this.collectingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<AppColorsExtension>()!;
    final cameraColor = isCameraConnected ? ext.success : colorScheme.error;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 0),
      child: Row(
        children: [
          Icon(
            Icons.factory_rounded,
            size: 18.sp,
            color: hasCollecting ? colorScheme.tertiary : colorScheme.primary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              stationName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasCollecting
                    ? colorScheme.tertiary
                    : colorScheme.onSurface,
              ),
            ),
          ),
          _CameraBadge(color: cameraColor),
          SizedBox(width: 6.w),
          if (hasCollecting)
            Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3.h),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                '$collectingCount $collectingLabel',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatelessWidget {
  final Color color;

  const _CameraBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          SizedBox(width: 3.w),
          Text(
            'CAM',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 8.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectingList extends StatelessWidget {
  final List<OrderModel> collectingVehicles;
  final String collectingLabel;

  const _CollectingList({
    required this.collectingVehicles,
    required this.collectingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, AppSpacing.smH, 14.w, 12.h),
      child: Column(
        children: collectingVehicles.map((order) {
          return _CollectingVehicleTile(
            licensePlate: order.vehicles?.vehicleLicensePlate ?? '---',
            collectingLabel: collectingLabel,
          );
        }).toList(),
      ),
    );
  }
}

class _CollectingVehicleTile extends StatelessWidget {
  final String licensePlate;
  final String collectingLabel;

  const _CollectingVehicleTile({
    required this.licensePlate,
    required this.collectingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: AppSpacing.smH),
      decoration: BoxDecoration(
        color: colorScheme.tertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded,
              size: 16.sp, color: colorScheme.tertiary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              licensePlate,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              collectingLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onTertiaryContainer,
                fontSize: 9.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
