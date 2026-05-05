import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:nguyenanh/core/theme/app_spacing.dart';
import 'package:nguyenanh/features/home/presentation/widgets/vehicle_detail_sheet.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

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
        dotColor = const Color(0xFFFF1744); // Vibrant Red Accent
      } else if (v.status == 'park') {
        dotColor = const Color(0xFFFFEA00); // Vibrant Yellow
      } else {
        dotColor = const Color(0xFF9E9E9E); // Grey for offline
      }

      return Marker(
        point: LatLng(v.latitude, v.longitude),
        width: 100,
        height: 80,
        alignment: Alignment.topCenter, // Align so the tip points at the coordinate
        child: GestureDetector(
          onTap: () => VehicleDetailSheet.show(context, v, widget.stations),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label Tooltip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(color: colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      v.vehicleName.isNotEmpty ? v.vehicleName : '---',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 10.sp,
                          ),
                    ),
                    if (v.licensePlate.isNotEmpty)
                      Text(
                        v.licensePlate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontSize: 8.sp,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              // Car Icon (SVG)
              Transform.rotate(
                angle: v.direction * (3.1415926535897932 / 180),
                child: Container(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(dotColor, BlendMode.modulate),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        0.33, 0.59, 0.11, 0, 30,
                        0.33, 0.59, 0.11, 0, 30,
                        0.33, 0.59, 0.11, 0, 30,
                        0, 0, 0, 1, 0,
                      ]),
                      child: SvgPicture.asset(
                        'assets/images/car.svg',
                        width: 24.w,
                        height: 24.w,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: theme.brightness == Brightness.dark
                  ? 'https://{s}.basemaps.cartocdn.com/rastertiles/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            CircleLayer(circles: circles),
            MarkerLayer(markers: markers),
          ],
        ),
        // Zoom controls
        Positioned(
          bottom: 8.h,
          left: 8.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                margin: EdgeInsets.only(bottom: 4.h),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20.sp,
                  icon: Icon(Icons.add_rounded, color: colorScheme.onSurface),
                  onPressed: () {
                    final zoom = mapController.camera.zoom;
                    mapController.move(mapController.camera.center, zoom + 1);
                  },
                ),
              ),
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20.sp,
                  icon: Icon(Icons.remove_rounded, color: colorScheme.onSurface),
                  onPressed: () {
                    final zoom = mapController.camera.zoom;
                    mapController.move(mapController.camera.center, zoom - 1);
                  },
                ),
              ),
            ],
          ),
        ),
        // Recenter control
        Positioned(
          bottom: 8.h,
          right: 8.w,
          child: FilledButton.tonalIcon(
            onPressed: () {
              mapController.move(center, 16);
            },
            icon: Icon(Icons.my_location_rounded, size: 14.sp),
            label: Text(
              'Vị trí ban đầu',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
              minimumSize: Size(0, 32.h),
            ),
          ),
        ),
      ],
    );
  }
}
