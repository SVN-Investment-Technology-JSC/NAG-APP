import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/theme/app_colors.dart';
import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/home/presentation/widgets/camera_dialog.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

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
            station: station,
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
  final Station station;
  final bool hasCollecting;
  final bool isCameraConnected;
  final int collectingCount;
  final String collectingLabel;

  const _StationHeader({
    required this.station,
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
              station.stationName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasCollecting
                    ? colorScheme.tertiary
                    : colorScheme.onSurface,
              ),
            ),
          ),
          _CameraBadge(isConnected: isCameraConnected, station: station),
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

class _CameraBadge extends StatefulWidget {
  final bool isConnected;
  final Station station;

  const _CameraBadge({required this.isConnected, required this.station});

  @override
  State<_CameraBadge> createState() => _CameraBadgeState();
}

class _CameraBadgeState extends State<_CameraBadge> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!widget.isConnected) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _CameraBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    } else if (!widget.isConnected && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppColorsExtension>()!;
    final colorScheme = theme.colorScheme;
    
    final color = widget.isConnected ? ext.success : colorScheme.error;
    final bgColor = widget.isConnected 
        ? const Color(0xFFECFDF5) // emerald-50
        : const Color(0xFFFEF2F2); // red-50
    final borderColor = widget.isConnected
        ? const Color(0xFFA7F3D0) // emerald-200
        : const Color(0xFFFECACA); // red-200
    
    final label = widget.isConnected ? 'Camera kết nối' : 'Camera ngắt kết nối';

    return GestureDetector(
      onTap: () => CameraDialog.show(context, widget.station),
      child: FadeTransition(
        opacity: _pulseAnimation,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_rounded,
                size: 14.sp,
                color: color,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
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
