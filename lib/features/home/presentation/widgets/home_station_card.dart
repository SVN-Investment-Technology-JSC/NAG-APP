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
  final bool canManualCamera;

  const HomeStationCard({
    super.key,
    required this.station,
    required this.collectingVehicles,
    required this.isCameraConnected,
    this.canManualCamera = true,
  });

  bool get _hasCollecting => collectingVehicles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StationHeader(
            station: station,
            hasCollecting: _hasCollecting,
            isCameraConnected: isCameraConnected,
            collectingCount: collectingVehicles.length,
            collectingLabel: l10n.collecting,
            canManualCamera: canManualCamera,
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
  final bool canManualCamera;

  const _StationHeader({
    required this.station,
    required this.hasCollecting,
    required this.isCameraConnected,
    required this.collectingCount,
    required this.collectingLabel,
    required this.canManualCamera,
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
            color: colorScheme.primary,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6.w,
              runSpacing: 4.h,
              children: [
                Text(
                  station.stationName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (hasCollecting)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      '$collectingCount $collectingLabel',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          _CameraBadge(isConnected: isCameraConnected, station: station, canManualCamera: canManualCamera),
        ],
      ),
    );
  }
}

class _CameraBadge extends StatefulWidget {
  final bool isConnected;
  final Station station;
  final bool canManualCamera;

  const _CameraBadge({
    required this.isConnected, 
    required this.station,
    required this.canManualCamera,
  });

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
    final bgColor = color.withValues(alpha: 0.1);
    final borderColor = color.withValues(alpha: 0.25);
    
    final label = widget.isConnected ? AppLocalizations.of(context)!.cameraConnected : AppLocalizations.of(context)!.cameraDisconnected;

    return GestureDetector(
      onTap: widget.canManualCamera ? () => CameraDialog.show(context, widget.station) : () {},
      child: Opacity(
        opacity: widget.canManualCamera ? 1.0 : 0.5,
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
        color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded,
              size: 16.sp, color: colorScheme.secondary),
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
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              collectingLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSecondaryContainer,
                fontSize: 9.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
