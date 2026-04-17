import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:vehicle_management/core/theme/app_colors.dart';
import 'package:vehicle_management/core/theme/app_spacing.dart';
import 'package:vehicle_management/features/stations/data/models/station_model.dart';
import 'package:vehicle_management/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class VehicleDetailSheet extends StatelessWidget {
  final VtrackingVehicle vehicle;
  final List<Station> stations;

  const VehicleDetailSheet({
    super.key,
    required this.vehicle,
    required this.stations,
  });

  static void show(
      BuildContext context, VtrackingVehicle v, List<Station> stations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (_) => VehicleDetailSheet(vehicle: v, stations: stations),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final status = _resolveStatus(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DragHandle(),
            SizedBox(height: AppSpacing.mdH),
            _VehicleHeaderRow(vehicle: vehicle, status: status),
            if (_showSubtitle) ...[
              SizedBox(height: AppSpacing.xsH),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  vehicle.vehicleName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            SizedBox(height: AppSpacing.mdH),
            Divider(color: colorScheme.outlineVariant),
            SizedBox(height: AppSpacing.smH),
            _DetailRow(
              icon: Icons.speed_rounded,
              label: l10n.speedLabel,
              value: '${vehicle.speed.toStringAsFixed(0)} km/h',
            ),
            SizedBox(height: 10.h),
            _DetailRow(
              icon: Icons.radar_rounded,
              label: l10n.distanceLabel,
              value: _distanceToNearestStation(),
            ),
            if (vehicle.geocoding.isNotEmpty) ...[
              SizedBox(height: 10.h),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: l10n.locationLabel,
                value: vehicle.geocoding,
              ),
            ],
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  bool get _showSubtitle =>
      vehicle.vehicleName.isNotEmpty &&
      vehicle.licensePlate.isNotEmpty &&
      vehicle.vehicleName != vehicle.licensePlate;

  _VehicleStatus _resolveStatus(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<AppColorsExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    switch (vehicle.status) {
      case 'run':
        return _VehicleStatus(const Color(0xFF10B981), l10n.vehicleRunning);
      case 'park':
        return _VehicleStatus(const Color(0xFFF59E0B), l10n.vehicleParked);
      default:
        return _VehicleStatus(colorScheme.error, l10n.vehicleOffline);
    }
  }

  String _distanceToNearestStation() {
    final type2 = stations
        .where((s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null)
        .toList();
    if (type2.isEmpty) return '---';

    const distance = Distance();
    double minDist = double.infinity;

    for (final s in type2) {
      final d = distance.as(
        LengthUnit.Meter,
        LatLng(vehicle.latitude, vehicle.longitude),
        LatLng(s.getLat!, s.getLng!),
      );
      if (d < minDist) minDist = d;
    }

    if (minDist >= 1000) return '${(minDist / 1000).toStringAsFixed(1)} km';
    return '${minDist.round()} m';
  }
}

class _VehicleStatus {
  final Color color;
  final String text;
  const _VehicleStatus(this.color, this.text);
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }
}

class _VehicleHeaderRow extends StatelessWidget {
  final VtrackingVehicle vehicle;
  final _VehicleStatus status;

  const _VehicleHeaderRow({
    required this.vehicle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.local_shipping_rounded, color: status.color, size: 24.sp),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            vehicle.licensePlate.isNotEmpty
                ? vehicle.licensePlate
                : vehicle.vehicleName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: status.color.withValues(alpha: 0.3)),
            ),
            child: Text(
              status.text,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: status.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.sp, color: colorScheme.onSurfaceVariant),
        SizedBox(width: 10.w),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
