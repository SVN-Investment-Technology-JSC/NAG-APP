import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/fleet_monitoring/data/models/fleet_models.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';

/// Trip route map, same reading as the web (TripRouteMap.tsx):
///  * outbound (blue) and return (orange) drawn as two parallel lanes with direction arrows,
///  * the trip's start point, the truck at the last position (rotated to its heading),
///  * numbered pins for the stops (red = cần kiểm tra), one flag per delivery place,
///  * yards / stations (not checked) as green circles.
class FxTripRouteMap extends StatelessWidget {
  final List<LatLng> route;
  final List<int> routeTs;
  /// Stops in display order — pin numbers follow this list (same numbers as the list under the map).
  final List<FleetEvent> stops;
  final List<FleetGeofence> yards;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final String? vehicleName;
  final String? plate;
  final EdgeInsets fitPadding;
  final MapController? controller;

  /// Extra layers drawn on top (e.g. the other vehicles on the overview map).
  final List<Widget> extraLayers;

  const FxTripRouteMap({
    super.key,
    required this.route,
    required this.routeTs,
    required this.stops,
    this.yards = const [],
    this.selectedId,
    this.onSelect,
    this.vehicleName,
    this.plate,
    this.fitPadding = const EdgeInsets.fromLTRB(36, 64, 36, 64),
    this.controller,
    this.extraLayers = const [],
  });

  /// Outbound until the truck leaves the delivery place (its last delivery / main stop ends), return after that.
  /// No delivery known: the turnaround is the point farthest from where the trip started.
  static (List<LatLng>, List<LatLng>) splitRoute(List<LatLng> route, List<int> routeTs, List<FleetEvent> stops) {
    if (route.length < 2) return (route, const []);
    var split = -1;
    final ends = stops
        .where((s) => s.risk?.level == 'delivery' || s.risk?.main == true)
        .map((s) => parseTime(s.endedAt ?? s.startedAt))
        .whereType<DateTime>()
        .map(toUnix)
        .toList();
    if (ends.isNotEmpty && routeTs.length == route.length) {
      final t = ends.reduce(math.max);
      split = routeTs.indexWhere((x) => x >= t);
      if (split < 0) split = route.length - 1;
    } else {
      const dist = Distance();
      var far = -1.0;
      for (var i = 0; i < route.length; i++) {
        final d = dist(route.first, route[i]);
        if (d > far) {
          far = d;
          split = i;
        }
      }
    }
    return (route.sublist(0, split + 1), route.sublist(split));
  }

  /// Bearing in degrees (0 = north, clockwise) of the last real movement.
  static double lastHeading(List<LatLng> route) {
    for (var i = route.length - 1; i > 0; i--) {
      final a = route[i - 1], b = route[i];
      if ((a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs() > 0.00012) {
        final dy = b.latitude - a.latitude;
        final dx = (b.longitude - a.longitude) * math.cos(a.latitude * math.pi / 180);
        return (math.atan2(dx, dy) * 180 / math.pi + 360) % 360;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final placed = stops.where((s) => s.lat != null && s.lon != null).toList();
    final fitPts = route.isNotEmpty ? route : placed.map((s) => LatLng(s.lat!, s.lon!)).toList();
    final (go, back) = splitRoute(route, routeTs, stops);
    final delivery = _deliveryPlaces(placed);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCameraFit: fitPts.length > 1
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(fitPts), padding: fitPadding, maxZoom: 16)
            : null,
        initialCenter: fitPts.isNotEmpty ? fitPts.first : const LatLng(17.49, 106.56),
        initialZoom: 14,
      ),
      children: [
        TileLayer(urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', userAgentPackageName: 'com.nguyenanh.nagapp'),
        CircleLayer(circles: [
          for (final y in yards)
            if (y.active && y.centerLat != null && y.centerLon != null)
              CircleMarker(
                point: LatLng(y.centerLat!, y.centerLon!),
                radius: y.radiusM ?? 100,
                useRadiusInMeter: true,
                color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                borderColor: const Color(0xFF16A34A),
                borderStrokeWidth: 1.5,
              ),
        ]),
        if (route.length > 1) FxDirectionalRouteLayer(go: go, back: back),
        MarkerLayer(markers: [
          if (route.length > 1)
            Marker(
              point: route.first,
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Color(0x550F172A), blurRadius: 3)],
                ),
              ),
            ),
          for (final g in delivery)
            Marker(
              point: g.center,
              width: 34,
              height: 34,
              child: GestureDetector(
                onTap: onSelect == null ? null : () => onSelect!(g.ids.first),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [BoxShadow(color: Color(0x660F172A), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.flag_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          for (final s in placed.where((s) => s.risk?.level != 'delivery'))
            Marker(
              point: LatLng(s.lat!, s.lon!),
              width: s.id == selectedId ? 40 : 34,
              height: s.id == selectedId ? 52 : 44,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: onSelect == null ? null : () => onSelect!(s.id),
                child: FxPin(
                  color: s.risk != null ? riskOf(s.risk!.level).color : severityOf(s.severity).color,
                  label: '${stops.indexOf(s) + 1}',
                  selected: s.id == selectedId,
                ),
              ),
            ),
          if (route.isNotEmpty)
            Marker(
              point: route.last,
              width: 120,
              height: 70,
              child: FxTruckMarker(heading: lastHeading(route), name: vehicleName, plate: plate),
            ),
        ]),
        ...extraLayers,
      ],
    );
  }

  /// All stops of one delivery place (wait + pour, ≤ 300 m apart, same trip) → one flag.
  List<({LatLng center, List<String> ids})> _deliveryPlaces(List<FleetEvent> placed) {
    const dist = Distance();
    final out = <({LatLng center, List<String> ids, String? trip})>[];
    for (final s in placed.where((x) => x.risk?.level == 'delivery')) {
      final p = LatLng(s.lat!, s.lon!);
      final g = out.where((x) => x.trip == s.tripId && dist(x.center, p) <= 300).firstOrNull;
      if (g != null) {
        g.ids.add(s.id);
      } else {
        out.add((center: p, ids: [s.id], trip: s.tripId));
      }
    }
    return [for (final g in out) (center: g.center, ids: g.ids)];
  }
}

/// Outbound / return lanes drawn a few pixels to the right of their travel direction (same road = two lanes),
/// with a white casing and direction chevrons every ~110 px. Recomputed when the zoom changes (offsets are in pixels).
class FxDirectionalRouteLayer extends StatelessWidget {
  final List<LatLng> go;
  final List<LatLng> back;
  const FxDirectionalRouteLayer({super.key, required this.go, required this.back});

  static const _lanePx = 4.0;
  static const _arrowEveryPx = 110.0;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final zoom = camera.zoom;
    final lanes = [
      (pts: go, color: kRouteGo),
      (pts: back, color: kRouteBack),
    ].where((x) => x.pts.length > 1).map((x) {
      final xy = _offsetPath(camera, _thin(x.pts), _lanePx, zoom);
      return (xy: xy, color: x.color);
    }).toList();

    final polylines = <Polyline>[];
    for (final l in lanes) {
      polylines.add(Polyline(points: [for (final p in l.xy) camera.unproject(p, zoom)], color: Colors.white.withValues(alpha: 0.95), strokeWidth: 8));
    }
    for (final l in lanes) {
      polylines.add(Polyline(points: [for (final p in l.xy) camera.unproject(p, zoom)], color: l.color, strokeWidth: 4.5));
    }

    final arrows = <Marker>[];
    for (final l in lanes) {
      var walked = 0.0, next = _arrowEveryPx / 2;
      for (var i = 1; i < l.xy.length; i++) {
        final a = l.xy[i - 1], b = l.xy[i];
        final seg = a.distanceTo(b);
        final ang = math.atan2(b.y - a.y, b.x - a.x);
        while (seg > 0 && next <= walked + seg) {
          final t = (next - walked) / seg;
          final p = math.Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
          arrows.add(Marker(
            point: camera.unproject(p, zoom),
            width: 16,
            height: 16,
            child: Transform.rotate(angle: ang, child: _Chevron(color: l.color)),
          ));
          next += _arrowEveryPx;
        }
        walked += seg;
      }
    }

    return Stack(children: [
      PolylineLayer(polylines: polylines),
      MarkerLayer(markers: arrows),
    ]);
  }

  /// At most ~700 points to keep zoom redraws light.
  static List<LatLng> _thin(List<LatLng> pts) {
    if (pts.length <= 700) return pts;
    final step = (pts.length / 700).ceil();
    final out = <LatLng>[for (var i = 0; i < pts.length; i += step) pts[i]];
    if (out.last != pts.last) out.add(pts.last);
    return out;
  }

  /// The path moved [px] pixels to the right of the travel direction (mitred corners, capped), in projected pixels.
  static List<math.Point<double>> _offsetPath(MapCamera camera, List<LatLng> pts, double px, double zoom) {
    final xy = <math.Point<double>>[];
    for (final p in pts) {
      final q = camera.project(p, zoom);
      if (xy.isEmpty || xy.last.distanceTo(q) >= 2) xy.add(q); // drop GPS jitter below 2 px
    }
    if (xy.length < 2) return xy;
    final nrm = <math.Point<double>>[];
    for (var i = 1; i < xy.length; i++) {
      final dx = xy[i].x - xy[i - 1].x, dy = xy[i].y - xy[i - 1].y;
      final l = math.sqrt(dx * dx + dy * dy);
      nrm.add(l == 0 ? const math.Point(0, 0) : math.Point(-dy / l, dx / l)); // right-hand normal (screen y down)
    }
    return [
      for (var i = 0; i < xy.length; i++)
        () {
          final n0 = nrm[math.max(0, i - 1)], n1 = nrm[math.min(nrm.length - 1, i)];
          var nx = n0.x + n1.x, ny = n0.y + n1.y;
          final l = math.sqrt(nx * nx + ny * ny);
          if (l < 1e-6) {
            nx = n1.x;
            ny = n1.y;
          } else {
            nx /= l;
            ny /= l;
          }
          final k = px / math.max(0.5, nx * n1.x + ny * n1.y);
          return math.Point(xy[i].x + nx * k, xy[i].y + ny * k);
        }(),
    ];
  }
}

class _Chevron extends StatelessWidget {
  final Color color;
  const _Chevron({required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(16, 16), painter: _ChevronPainter(color));
}

class _ChevronPainter extends CustomPainter {
  final Color color;
  _ChevronPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.18)
      ..lineTo(size.width * 0.72, size.height * 0.5)
      ..lineTo(size.width * 0.3, size.height * 0.82);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, base..color = color..strokeWidth = 5);
    canvas.drawPath(path, base..color = Colors.white..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.color != color;
}

/// Tear-drop pin with a number (stop on the route).
class FxPin extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  const FxPin({super.key, required this.color, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final w = selected ? 40.0 : 34.0;
    return SizedBox(
      width: w,
      height: w * 1.3,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Icon(Icons.location_on, size: w * 1.3, color: color, shadows: const [Shadow(color: Color(0x660F172A), blurRadius: 4)]),
          Positioned(
            top: w * 0.27,
            child: Container(
              width: w * 0.5,
              height: w * 0.5,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Text(label, style: TextStyle(fontSize: w * 0.3, fontWeight: FontWeight.w900, color: color, height: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The truck at its last position: top-down car icon rotated to the heading, with name / plate label.
class FxTruckMarker extends StatelessWidget {
  final double? heading;
  final String? name;
  final String? plate;
  final Color? border;
  final double size;
  final bool dim;
  final Color? statusColor;
  const FxTruckMarker({super.key, this.heading, this.name, this.plate, this.border, this.size = 40, this.dim = false, this.statusColor});

  @override
  Widget build(BuildContext context) {
    final car = Transform.rotate(
      angle: (heading ?? 0) * math.pi / 180,
      child: SvgPicture.asset('assets/images/car.svg', width: size, height: size * 9 / 16, fit: BoxFit.contain),
    );
    return Opacity(
      opacity: dim ? 0.55 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (name != null || plate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: border ?? const Color(0xFFD1D5DB)),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (name != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (statusColor != null) ...[
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                    ],
                    Text(name!,
                      maxLines: 1,
                      style: TextStyle(fontSize: 10, height: 1.2, fontWeight: FontWeight.w800, color: border == FxTokens.red ? FxTokens.red : const Color(0xFF333333))),
                  ]),
                if (plate != null) Text(plate!, maxLines: 1, style: const TextStyle(fontSize: 8.5, height: 1.2, color: Color(0xFF666666))),
              ]),
            ),
          const SizedBox(height: 2),
          car,
        ],
      ),
    );
  }
}

/// Legend row for the trip maps.
class FxRouteLegend extends StatelessWidget {
  const FxRouteLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    Widget line(Color c, String l) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 16, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(l, style: t.tiny),
        ]);
    Widget dot(Color c, String l, {IconData? icon}) => Row(mainAxisSize: MainAxisSize.min, children: [
          icon != null
              ? Icon(icon, size: 12, color: c)
              : Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(l, style: t.tiny),
        ]);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        line(kRouteGo, 'Chiều đi'),
        line(kRouteBack, 'Chiều về'),
        dot(const Color(0xFF16A34A), 'Xuất phát'),
        dot(riskOf('check').color, 'Cần kiểm tra', icon: Icons.location_on),
        dot(const Color(0xFF16A34A), 'Điểm giao', icon: Icons.flag_rounded),
        dot(riskOf('normal').color, 'Bình thường', icon: Icons.location_on),
      ],
    );
  }
}
