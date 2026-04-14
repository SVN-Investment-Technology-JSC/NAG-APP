import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:vehicle_management/core/theme/app_spacing.dart';
import 'package:vehicle_management/features/home/presentation/widgets/vehicle_detail_sheet.dart';
import 'package:vehicle_management/features/order/data/models/order_model.dart';
import 'package:vehicle_management/features/stations/data/models/station_model.dart';
import 'package:vehicle_management/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:vehicle_management/l10n/app_localizations.dart';

class HomeMapSection extends StatefulWidget {
  final List<Station> stations;
  final List<VtrackingVehicle> vtrackingVehicles;
  final List<OrderModel> collectingOrders;

  const HomeMapSection({
    super.key,
    required this.stations,
    required this.vtrackingVehicles,
    required this.collectingOrders,
  });

  @override
  State<HomeMapSection> createState() => _HomeMapSectionState();
}

class _HomeMapSectionState extends State<HomeMapSection> {
  final MapController _mapController = MapController();
  bool _mapExpanded = true;

  List<Station> get _stationsWithGps =>
      widget.stations.where((s) => s.getLat != null && s.getLng != null).toList();

  @override
  Widget build(BuildContext context) {
    if (_stationsWithGps.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xsH),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        color: colorScheme.surfaceContainerLow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            _MapHeader(
              mapExpanded: _mapExpanded,
              collectingCount: widget.collectingOrders.length,
              onToggle: () => setState(() => _mapExpanded = !_mapExpanded),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              height: _mapExpanded ? 200.h : 0,
              child: _mapExpanded
                  ? _MapView(
                      mapController: _mapController,
                      center: _mapCenter(),
                      circles: _buildGeofenceCircles(),
                      markers: _buildVehicleMarkers(context),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  LatLng _mapCenter() {
    final valid = widget.stations
        .where((s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null)
        .toList();
    if (valid.isEmpty) return const LatLng(10.8231, 106.6297);

    double sumLat = 0, sumLng = 0;
    for (final s in valid) {
      sumLat += s.getLat!;
      sumLng += s.getLng!;
    }
    return LatLng(sumLat / valid.length, sumLng / valid.length);
  }

  List<CircleMarker> _buildGeofenceCircles() {
    return widget.stations
        .where((s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null)
        .map((s) => CircleMarker(
              point: LatLng(s.getLat!, s.getLng!),
              radius: s.stationGpsGeofencing.toDouble(),
              useRadiusInMeter: true,
              color: const Color(0x1406B6D4),
              borderColor: const Color(0xFF06B6D4),
              borderStrokeWidth: 1.5,
            ))
        .toList();
  }

  List<Marker> _buildVehicleMarkers(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return widget.vtrackingVehicles.map((v) {
      Color dotColor;
      if (v.status == 'run') {
        dotColor = const Color(0xFF10B981);
      } else if (v.status == 'park') {
        dotColor = const Color(0xFFF59E0B);
      } else {
        dotColor = colorScheme.error;
      }

      return Marker(
        point: LatLng(v.latitude, v.longitude),
        width: 18,
        height: 18,
        child: GestureDetector(
          onTap: () => VehicleDetailSheet.show(context, v, widget.stations),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.surface,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _MapHeader extends StatelessWidget {
  final bool mapExpanded;
  final int collectingCount;
  final VoidCallback onToggle;

  const _MapHeader({
    required this.mapExpanded,
    required this.collectingCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Icon(Icons.map_rounded, size: 18.sp, color: colorScheme.primary),
            SizedBox(width: AppSpacing.sm),
            Text(
              l10n.stationOverview,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (collectingCount > 0)
              Container(
                margin: EdgeInsets.only(right: AppSpacing.sm),
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3.h),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '$collectingCount ${l10n.collecting}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            Icon(
              mapExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final List<CircleMarker> circles;
  final List<Marker> markers;

  const _MapView({
    required this.mapController,
    required this.center,
    required this.circles,
    required this.markers,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        CircleLayer(circles: circles),
        MarkerLayer(markers: markers),
      ],
    );
  }
}
