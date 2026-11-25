import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/vehicle_detail_sheet_v2.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';

/// v2 of `VehicleMapWidget` (same constructor, same map / marker / controls behaviour), new chrome.
class VehicleMapWidgetV2 extends StatefulWidget {
  final VtrackingVehicle vtracking;
  final List<Station> stations;
  final bool isFullscreen;

  const VehicleMapWidgetV2({
    super.key,
    required this.vtracking,
    required this.stations,
    this.isFullscreen = false,
  });

  @override
  State<VehicleMapWidgetV2> createState() => _VehicleMapWidgetV2State();
}

class _VehicleMapWidgetV2State extends State<VehicleMapWidgetV2> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final center = LatLng(widget.vtracking.latitude, widget.vtracking.longitude);

    final circles = widget.stations
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

    Widget carSvg = SvgPicture.asset(
      'assets/images/car.svg',
      width: 36.w,
      height: 36.w,
      fit: BoxFit.contain,
    );

    if (widget.vtracking.status == 'stop' || widget.vtracking.status == 'park') {
      carSvg = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0, 0, 1, 0, 0, // R' = B
          0, 1, 0, 0, 0, // G' = G
          1, 0, 0, 0, 0, // B' = R
          0, 0, 0, 1, 0, // A' = A
        ]),
        child: carSvg,
      );
    } else if (widget.vtracking.status == 'offline') {
      carSvg = Opacity(
        opacity: 0.6,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: carSvg,
        ),
      );
    }

    final marker = Marker(
      point: center,
      width: 80.w,
      height: 80.w,
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: () => VehicleDetailSheetV2.show(context, widget.vtracking, widget.stations),
            child: Transform.rotate(
              angle: widget.vtracking.direction * (3.1415926535897932 / 180),
              child: carSvg,
            ),
          ),
          Positioned(
            bottom: 48.w + 2.h,
            child: GestureDetector(
              onTap: () => VehicleDetailSheetV2.show(context, widget.vtracking, widget.stations),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6.r),
                  boxShadow: const [BoxShadow(color: Color(0x330F172A), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.vtracking.vehicleName.isNotEmpty ? widget.vtracking.vehicleName : '---',
                      maxLines: 1,
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                    ),
                    if (widget.vtracking.licensePlate.isNotEmpty)
                      Text(
                        widget.vtracking.licensePlate,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 8.sp,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontFeatures: FxTokens.tabular,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Widget glassButton({required IconData icon, required String tooltip, required VoidCallback onTap}) =>
        FxMapButton(icon: icon, tooltip: tooltip, onTap: onTap);

    final Widget mapStack = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: center, initialZoom: 16, maxZoom: 20.0),
          children: [
            TileLayer(
              urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.nguyenanh.nagapp',
            ),
            CircleLayer(circles: circles),
            MarkerLayer(markers: [marker]),
          ],
        ),
        Positioned(
          bottom: 10.h,
          left: 10.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              glassButton(
                icon: Icons.add_rounded,
                tooltip: 'Phóng to',
                onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
              ),
              SizedBox(height: 6.h),
              glassButton(
                icon: Icons.remove_rounded,
                tooltip: 'Thu nhỏ',
                onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 10.h,
          right: 10.w,
          child: Material(
            color: t.card,
            shape: StadiumBorder(side: BorderSide(color: t.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _mapController.move(center, 16),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location_rounded, size: 15.sp, color: t.ink(FxTokens.blue)),
                    SizedBox(width: 6.w),
                    Text(
                      'Vị trí ban đầu',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: t.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!widget.isFullscreen)
          Positioned(
            top: 10.h,
            right: 10.w,
            child: glassButton(
              icon: Icons.fullscreen_rounded,
              tooltip: 'Toàn màn hình',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: FxTokens.of(context).bg,
                      body: SafeArea(
                        child: Stack(
                          children: [
                            VehicleMapWidgetV2(
                              vtracking: widget.vtracking,
                              stations: widget.stations,
                              isFullscreen: true,
                            ),
                            Positioned(
                              top: 16.h,
                              left: 16.w,
                              child: FxMapButton(
                                icon: Icons.arrow_back_rounded,
                                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    if (widget.isFullscreen) {
      return mapStack;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 250.h,
          child: mapStack,
        ),
      ],
    );
  }
}
