import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/features/vtracking/data/models/vtracking_vehicle.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// Vehicle quick-info bottom sheet (v2). Same reverse-geocoding call, status mapping and
/// "distance to the nearest type-2 station" as [VehicleDetailSheet]; new presentation.
class VehicleDetailSheetV2 extends StatefulWidget {
  final VtrackingVehicle vehicle;
  final List<Station> stations;

  const VehicleDetailSheetV2({
    super.key,
    required this.vehicle,
    required this.stations,
  });

  static void show(BuildContext context, VtrackingVehicle v, List<Station> stations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FxTokens.of(context).bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => VehicleDetailSheetV2(vehicle: v, stations: stations),
    );
  }

  @override
  State<VehicleDetailSheetV2> createState() => _VehicleDetailSheetV2State();
}

class _VehicleDetailSheetV2State extends State<VehicleDetailSheetV2> {
  String _address = '';
  bool _isLoadingAddress = true;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _address = widget.vehicle.geocoding;
    _fetchAddress();
  }

  Future<void> _fetchAddress() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nguyenanhdonghoi.com/api/geocode/reverse',
        queryParameters: {
          'lat': widget.vehicle.latitude,
          'lng': widget.vehicle.longitude,
        },
      );
      if (response.statusCode == 200 && response.data['address'] != null) {
        if (mounted) {
          setState(() {
            _address = _formatAddress(response.data['address']);
            _isLoadingAddress = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingAddress = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  String _formatAddress(String? raw) {
    if (raw == null || raw.isEmpty) return _address;
    final cleaned = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != 'null' && s != 'undefined')
        .join(', ');
    if (cleaned.isEmpty) return _address;
    return cleaned;
  }

  bool get _showSubtitle =>
      widget.vehicle.vehicleName.isNotEmpty &&
      widget.vehicle.licensePlate.isNotEmpty &&
      widget.vehicle.vehicleName != widget.vehicle.licensePlate;

  ({Color color, String text}) _resolveStatus(AppLocalizations l10n) {
    switch (widget.vehicle.status) {
      case 'run':
        return (color: FxTokens.emerald, text: l10n.vehicleRunning);
      case 'park':
        return (color: FxTokens.amber, text: l10n.vehicleParked);
      default:
        return (color: FxTokens.red, text: l10n.vehicleOffline);
    }
  }

  String _distanceToNearestStation() {
    final type2 = widget.stations.where((s) => s.stationTypeId == 2 && s.getLat != null && s.getLng != null).toList();
    if (type2.isEmpty) return '---';

    const distance = Distance();
    double minDist = double.infinity;

    for (final s in type2) {
      final d = distance.as(
        LengthUnit.Meter,
        LatLng(widget.vehicle.latitude, widget.vehicle.longitude),
        LatLng(s.getLat!, s.getLng!),
      );
      if (d < minDist) minDist = d;
    }

    if (minDist >= 1000) return '${(minDist / 1000).toStringAsFixed(1)} km';
    return '${minDist.round()} m';
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final status = _resolveStatus(l10n);
    final v = widget.vehicle;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header band
          Container(
            padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 16.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [status.color.withValues(alpha: t.dark ? 0.30 : 0.14), t.bg],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 14.h),
                    decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2.r)),
                  ),
                ),
                Row(
                  children: [
                    FxIconBadge(icon: Icons.local_shipping_rounded, tone: status.color, size: 44),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.licensePlate.isNotEmpty ? v.licensePlate : v.vehicleName,
                            style: t.h1.copyWith(fontSize: 19.sp, fontFeatures: FxTokens.tabular),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_showSubtitle) ...[
                            SizedBox(height: 2.h),
                            Text(v.vehicleName, style: t.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 150.w),
                      child: FxPill(label: status.text, tone: status.color, dot: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FxGrid(
                    columns: 2,
                    children: [
                      FxInfoTile(icon: Icons.speed_rounded, label: l10n.speedLabel, value: '${v.speed.toStringAsFixed(0)} km/h'),
                      FxInfoTile(icon: Icons.radar_rounded, label: l10n.distanceLabel, value: _distanceToNearestStation()),
                    ],
                  ),
                  if (_address.isNotEmpty || _isLoadingAddress) _addressTile(t, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressTile(FxTokens t, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(color: t.cardAlt, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: t.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, size: 17.sp, color: t.ink(FxTokens.blue)),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.locationLabel.toUpperCase(), style: t.overline),
                SizedBox(height: 4.h),
                if (_isLoadingAddress)
                  Row(
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8, color: t.textMuted)),
                      SizedBox(width: 8.w),
                      Expanded(child: Text('Đang lấy địa chỉ...', style: t.small)),
                    ],
                  )
                else
                  Text(_address, style: t.body.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
