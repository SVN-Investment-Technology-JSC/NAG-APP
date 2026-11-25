import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fuel_analysis.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';

// ─── Axis helpers ───────────────────────────────────────────────────────────

/// A "nice" step (1, 2, 2.5, 5 × 10^n) giving about [ticks] intervals over [range].
double niceStep(double range, int ticks) {
  if (range <= 0 || !range.isFinite) return 1;
  final raw = range / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5.0 : 10.0)));
  return nf * mag;
}

/// [lo, hi] widened to multiples of a nice step.
({double lo, double hi, double step}) niceScale(double lo, double hi, {int ticks = 4}) {
  if (hi <= lo) hi = lo + 1;
  final step = niceStep(hi - lo, ticks);
  return (lo: (lo / step).floor() * step, hi: (hi / step).ceil() * step, step: step);
}

/// Time step (seconds) giving about 4–6 labels over [span] seconds.
int niceTimeStep(double span) {
  const steps = [300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400, 172800];
  for (final s in steps) {
    if (span / s <= 5) return s;
  }
  return 172800;
}

/// Local time zone offset, so axis ticks land on local whole hours / midnights.
int get _tz => DateTime.now().timeZoneOffset.inSeconds;

String _axisNum(double v, double step) => fmtNum(v, step < 1 ? 1 : 0);

// ─── Time-series chart ──────────────────────────────────────────────────────

class FxBand {
  final int from;
  final int to;
  final Color color;
  const FxBand(this.from, this.to, this.color);
}

class FxMark {
  final int ts;
  final Color color;
  const FxMark(this.ts, this.color);
}

/// Line chart over time with clear axes: nice Y ticks (all labelled), time ticks on local whole hours,
/// crosshair tooltip, optional shaded bands (e.g. moving phases) and event marks.
class FxTimeChart extends StatelessWidget {
  final List<FuelRow> rows;
  final double? Function(FuelRow) pick;
  final Color color;
  final String unit;
  final double? fixedMin;
  final double? fixedMax;
  final double? yStep;
  final List<FxBand> bands;
  final List<FxMark> marks;
  final int gapS;
  final int digits;

  const FxTimeChart({
    super.key,
    required this.rows,
    required this.pick,
    required this.color,
    required this.unit,
    this.fixedMin,
    this.fixedMax,
    this.yStep,
    this.bands = const [],
    this.marks = const [],
    this.gapS = 600,
    this.digits = 1,
  });

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final pts = decimate(rows.where((r) => pick(r) != null).toList(), 500);
    if (pts.length < 2) {
      return Center(child: Text('Chưa có dữ liệu trong khoảng này', style: t.small));
    }

    // x = local epoch seconds (so ticks land on local hours)
    final tz = _tz;
    final spots = <FlSpot>[];
    for (var i = 0; i < pts.length; i++) {
      if (i > 0 && pts[i].ts - pts[i - 1].ts > gapS) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot((pts[i].ts + tz).toDouble(), pick(pts[i])!));
    }
    final minX = (pts.first.ts + tz).toDouble(), maxX = (pts.last.ts + tz).toDouble();
    final span = math.max(60.0, maxX - minX);
    final xStep = niceTimeStep(span).toDouble();

    final ys = pts.map((r) => pick(r)!);
    final dataLo = ys.reduce(math.min), dataHi = ys.reduce(math.max);
    double lo, hi, step;
    if (fixedMin != null && fixedMax != null && yStep != null) {
      lo = fixedMin!;
      hi = fixedMax!;
      step = yStep!;
    } else {
      final s = niceScale(fixedMin ?? math.min(0, dataLo), math.max(dataHi, (fixedMin ?? 0) + 1));
      lo = s.lo;
      hi = s.hi;
      step = s.step;
    }

    final grid = t.divider;
    final labelStyle = TextStyle(fontSize: 9.5.sp, color: t.textMuted, fontFeatures: FxTokens.tabular);
    final multiDay = span > 26 * 3600;
    final hm = DateFormat('HH:mm'), dm = DateFormat('dd/MM');
    String timeLabel(double x) {
      final d = DateTime.fromMillisecondsSinceEpoch(((x - tz) * 1000).round());
      if (xStep >= 86400) return dm.format(d);
      if (multiDay && d.hour == 0 && d.minute == 0) return dm.format(d);
      return hm.format(d);
    }

    bool onStep(double v, double s) {
      final r = (v / s).round() * s;
      return (v - r).abs() < s * 1e-6;
    }

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: lo,
        maxY: hi,
        clipData: const FlClipData.all(),
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: [
            for (final b in bands)
              if (b.to + tz > minX && b.from + tz < maxX)
                VerticalRangeAnnotation(
                  x1: math.max(minX, (b.from + tz).toDouble()),
                  x2: math.min(maxX, (b.to + tz).toDouble()),
                  color: b.color,
                ),
          ],
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: step,
          verticalInterval: xStep,
          getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 1),
          getDrawingVerticalLine: (_) => FlLine(color: grid.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [3, 4]),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: t.border), left: BorderSide.none, right: BorderSide.none, top: BorderSide.none),
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            for (final m in marks)
              if (m.ts + tz >= minX && m.ts + tz <= maxX)
                VerticalLine(
                  x: (m.ts + tz).toDouble(),
                  color: m.color.withValues(alpha: 0.85),
                  strokeWidth: 1.4,
                  dashArray: [4, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(left: 2, top: 0),
                    style: TextStyle(fontSize: 9.sp, color: m.color, fontWeight: FontWeight.w900),
                    labelResolver: (_) => '!',
                  ),
                ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38.w,
              interval: step,
              getTitlesWidget: (v, meta) => onStep(v, step)
                  ? SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(_axisNum(v, step), style: labelStyle),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24.h,
              interval: xStep,
              getTitlesWidget: (v, meta) => onStep(v, xStep) && v > minX + xStep * 0.15 && v < maxX - xStep * 0.15
                  ? SideTitleWidget(meta: meta, space: 6, child: Text(timeLabel(v), style: labelStyle))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (bar, idx) => idx
              .map((_) => TouchedSpotIndicatorData(
                    FlLine(color: t.textMuted.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [3, 3]),
                    FlDotData(
                      getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 4, color: color, strokeWidth: 2, strokeColor: t.card),
                    ),
                  ))
              .toList(),
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => t.dark ? const Color(0xFF020617) : const Color(0xFF0F172A),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (items) => items.map((s) {
              final d = DateTime.fromMillisecondsSinceEpoch(((s.x - tz) * 1000).round());
              return LineTooltipItem(
                '${fmtNum(s.y, digits)} $unit\n',
                const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(
                    text: DateFormat(multiDay ? 'HH:mm dd/MM' : 'HH:mm').format(d),
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
              ),
            ),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

// ─── Donut ──────────────────────────────────────────────────────────────────

class FxDonut extends StatelessWidget {
  final List<({String name, double value, Color color})> parts;
  final String centerValue;
  final String centerLabel;
  final double size;

  const FxDonut({super.key, required this.parts, required this.centerValue, required this.centerLabel, this.size = 132});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return SizedBox(
      width: size.w,
      height: size.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 2,
              centerSpaceRadius: size.w * 0.33,
              sections: [
                for (final p in parts) PieChartSectionData(value: p.value, color: p.color, radius: size.w * 0.15, showTitle: false),
              ],
            ),
            duration: Duration.zero,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerValue, style: t.num(17.sp)),
              SizedBox(height: 2.h),
              Text(centerLabel, style: t.tiny),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Comparison bars ────────────────────────────────────────────────────────

/// Vertical bars with value labels on top and a nice Y axis.
class FxCompareBars extends StatelessWidget {
  final List<({String name, double v, Color color})> items;
  final String unit;

  const FxCompareBars({super.key, required this.items, required this.unit});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final max = items.map((e) => e.v).fold<double>(0, math.max);
    final s = niceScale(0, max * 1.15, ticks: 4);
    final labelStyle = TextStyle(fontSize: 9.5.sp, color: t.textMuted, fontFeatures: FxTokens.tabular);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: s.hi,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: s.step,
          getDrawingHorizontalLine: (_) => FlLine(color: t.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: t.border))),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34.w,
              interval: s.step,
              getTitlesWidget: (v, meta) =>
                  SideTitleWidget(meta: meta, space: 6, child: Text(_axisNum(v, s.step), style: labelStyle)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26.h,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                return SideTitleWidget(meta: meta, space: 6, child: Text(items[i].name, style: labelStyle));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4,
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              fmtNum(rod.toY, 1),
              TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: t.text, fontFeatures: FxTokens.tabular),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: const [0],
              barRods: [
                BarChartRodData(
                  toY: items[i].v,
                  width: 34.w,
                  color: items[i].color,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8.r)),
                ),
              ],
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}
