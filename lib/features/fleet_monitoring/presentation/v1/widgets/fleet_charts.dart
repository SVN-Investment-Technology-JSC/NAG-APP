import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fleet_utils.dart';
import 'package:nguyenanh/features/fleet_monitoring/presentation/fuel_analysis.dart';

/// Time-series line chart (x = epoch seconds). Missing values break the line; gaps > [gapS] also break it.
class FleetLineChart extends StatelessWidget {
  final List<FuelRow> rows;
  final double? Function(FuelRow) pick;
  final Color color;
  final String unit;
  final double? minY;
  final double? maxY;
  final bool filled;
  final List<({int ts, Color color})> marks;
  final int gapS;

  const FleetLineChart({
    super.key,
    required this.rows,
    required this.pick,
    required this.color,
    this.unit = '',
    this.minY,
    this.maxY,
    this.filled = false,
    this.marks = const [],
    this.gapS = 600,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pts = decimate(rows.where((r) => pick(r) != null).toList(), 450);
    if (pts.length < 2) {
      return Center(child: Text('Chưa có dữ liệu', style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant)));
    }
    final spots = <FlSpot>[];
    for (var i = 0; i < pts.length; i++) {
      if (i > 0 && pts[i].ts - pts[i - 1].ts > gapS) spots.add(FlSpot.nullSpot);
      spots.add(FlSpot(pts[i].ts.toDouble(), pick(pts[i])!));
    }
    final minX = pts.first.ts.toDouble(), maxX = pts.last.ts.toDouble();
    final span = (maxX - minX).clamp(60, double.infinity);
    final withDate = span > 36 * 3600;
    final ys = pts.map((r) => pick(r)!);
    final lo = minY ?? ys.reduce((a, b) => a < b ? a : b);
    var hi = maxY ?? ys.reduce((a, b) => a > b ? a : b);
    if (hi <= lo) hi = lo + 1;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: lo,
        maxY: hi,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.4), strokeWidth: 0.6),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            for (final m in marks)
              if (m.ts >= minX && m.ts <= maxX)
                VerticalLine(x: m.ts.toDouble(), color: m.color.withValues(alpha: 0.8), strokeWidth: 1.5, dashArray: [4, 3]),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox.shrink()
                  : Text(fmtNum(v, 0), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: span / 4,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(withDate ? fmtUnix(v.toInt(), withDate: true) : fmtUnix(v.toInt()),
                          style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.inverseSurface,
            getTooltipItems: (items) => items
                .map((s) => LineTooltipItem(
                      '${fmtUnix(s.x.toInt(), withDate: withDate)}\n${fmtNum(s.y, 1)}${unit.isNotEmpty ? ' $unit' : ''}',
                      TextStyle(color: cs.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 1.6,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: filled, color: color.withValues(alpha: 0.12)),
          ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}

/// Donut of the time split (moving / standing on / standing off / unknown).
class TimeSplitDonut extends StatelessWidget {
  final List<({String name, double value, Color color})> parts;
  final double total;

  const TimeSplitDonut({super.key, required this.parts, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 130.w,
          height: 130.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 1,
                  centerSpaceRadius: 42.w,
                  sections: [
                    for (final p in parts) PieChartSectionData(value: p.value, color: p.color, radius: 18.w, showTitle: false),
                  ],
                ),
                duration: Duration.zero,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${fmtNum(total / 3600, 1)} h', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
                  Text('Tổng', style: TextStyle(fontSize: 10.sp, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in parts)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 3.h),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                      SizedBox(width: 6.w),
                      Expanded(child: Text(p.name, style: TextStyle(fontSize: 11.sp))),
                      Text('${fmtNum(p.value / 3600, 1)} h (${fmtNum(p.value / total * 100, 0)}%)',
                          style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple horizontal bars (current vs 7-day vs 30-day L/100 km).
class CompareBars extends StatelessWidget {
  final List<({String name, double v, Color color})> items;
  final String unit;

  const CompareBars({super.key, required this.items, required this.unit});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final max = items.map((e) => e.v).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Row(
              children: [
                SizedBox(width: 92.w, child: Text(it.name, style: TextStyle(fontSize: 11.sp, color: cs.onSurfaceVariant))),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 16.h,
                        width: max <= 0 ? 0 : c.maxWidth * (it.v / max).clamp(0.02, 1),
                        decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(4.r)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                SizedBox(
                  width: 44.w,
                  child: Text(fmtNum(it.v, 1), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(unit, style: TextStyle(fontSize: 10.sp, color: cs.outline)),
        ),
      ],
    );
  }
}
