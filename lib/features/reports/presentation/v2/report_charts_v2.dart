import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';

// ─── Axis helpers (same rules as the v2 fleet charts) ───────────────────────

/// A "nice" step (1, 2, 2.5, 5 × 10^n) giving about [ticks] intervals over [range].
double reportNiceStep(double range, int ticks) {
  if (range <= 0 || !range.isFinite) return 1;
  final raw = range / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / mag;
  final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5.0 : 10.0)));
  return nf * mag;
}

/// [lo, hi] widened to multiples of a nice step. With [integer], the step is a whole number (counts).
({double lo, double hi, double step}) reportNiceScale(double lo, double hi, {int ticks = 4, bool integer = false}) {
  if (hi <= lo) hi = lo + 1;
  var step = reportNiceStep(hi - lo, ticks);
  if (integer) {
    if (step < 1) {
      step = 1;
    } else if (step != step.roundToDouble()) {
      step = step.floorToDouble();
    }
  }
  return (lo: (lo / step).floor() * step, hi: (hi / step).ceil() * step, step: step);
}

bool _onStep(double v, double s) {
  final r = (v / s).round() * s;
  return (v - r).abs() < s * 1e-6;
}

String _axisNum(double v) => NumberFormat('#,##0', 'vi').format(v);

// ─── Production bar chart ───────────────────────────────────────────────────

/// Bars of total trips per period with a fixed, fully labelled Y axis (nice ticks, gridlines on every tick),
/// a dashed average line, value labels on the bars and a detailed tooltip on tap / long-press.
/// Scrolls horizontally (axis stays fixed) when the bars don't fit.
class ProductionBarChartV2 extends StatefulWidget {
  final List<ProductionSeriesItem> series;
  final double average;
  final ScrollController scrollController;
  final String totalLabel;

  const ProductionBarChartV2({
    super.key,
    required this.series,
    required this.average,
    required this.scrollController,
    required this.totalLabel,
  });

  @override
  State<ProductionBarChartV2> createState() => _ProductionBarChartV2State();
}

class _ProductionBarChartV2State extends State<ProductionBarChartV2> {
  int? _touched;

  @override
  void didUpdateWidget(ProductionBarChartV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series) _touched = null;
  }

  String _shortLabel(String period) {
    final date = DateTime.tryParse(period);
    return date != null ? DateFormat('dd/MM').format(date) : period;
  }

  String _longLabel(String period) {
    final date = DateTime.tryParse(period);
    return date != null ? DateFormat('dd/MM/yyyy').format(date) : period;
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final data = widget.series;
    final avg = widget.average;

    var maxV = 0.0;
    for (final item in data) {
      if (item.totalOrders > maxV) maxV = item.totalOrders.toDouble();
    }
    // headroom for the value labels above the bars
    final s = reportNiceScale(0, math.max(math.max(maxV, avg) * 1.18, 4), ticks: 4, integer: true);

    final axisStyle = TextStyle(fontSize: 9.5.sp, color: t.textMuted, fontFeatures: FxTokens.tabular);
    final bottomReserved = 26.h;
    final touched = _touched != null && _touched! < data.length ? _touched : null;
    final tooltipBg = t.dark ? const Color(0xFF020617) : const Color(0xFF0F172A);
    final completedInk = Color.lerp(FxTokens.emerald, Colors.white, 0.45)!;

    return LayoutBuilder(builder: (context, c) {
      final axisW = 34.w;
      final viewW = math.max(1.0, c.maxWidth - axisW);
      final fits = data.isEmpty || viewW / data.length >= 40.w;
      final slot = fits ? viewW / math.max(1, data.length) : 46.w;
      final chartW = fits ? viewW : data.length * slot;
      final barW = math.min(slot * 0.56, 22.w);

      // Fixed left axis: an empty bar chart with the same scale, so ticks line up exactly with the scrolling plot.
      final axis = BarChart(
        BarChartData(
          minY: 0,
          maxY: s.hi,
          barGroups: const [],
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: axisW - 2,
                interval: s.step,
                getTitlesWidget: (v, meta) => _onStep(v, s.step)
                    ? SideTitleWidget(
                        meta: meta,
                        space: 6,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                        child: Text(_axisNum(v), style: axisStyle),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: bottomReserved,
                getTitlesWidget: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        duration: Duration.zero,
      );

      final plot = BarChart(
        BarChartData(
          minY: 0,
          maxY: s.hi,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: s.step,
            getDrawingHorizontalLine: (_) => FlLine(color: t.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              // the average value itself is shown in the legend under the chart
              HorizontalLine(
                y: avg,
                color: FxTokens.violet.withValues(alpha: 0.75),
                strokeWidth: 1.4,
                dashArray: [6, 4],
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: bottomReserved,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  final strong = i == touched || (touched == null && i == data.length - 1);
                  return SideTitleWidget(
                    meta: meta,
                    space: 6,
                    child: SizedBox(
                      width: slot - 2,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _shortLabel(data[i].period),
                          style: axisStyle.copyWith(
                            color: strong ? t.text : t.textMuted,
                            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            handleBuiltInTouches: false,
            allowTouchBarBackDraw: true,
            touchExtraThreshold: EdgeInsets.symmetric(horizontal: math.max(0, (slot - barW) / 2)),
            touchCallback: (event, response) {
              final i = response?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent) {
                setState(() => _touched = (i == null || i == _touched) ? null : i);
              } else if (event is FlLongPressStart || event is FlLongPressMoveUpdate) {
                if (i != null && i != _touched) setState(() => _touched = i);
              }
            },
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipRoundedRadius: 10,
              tooltipPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              tooltipMargin: 2,
              maxContentWidth: 220,
              getTooltipColor: (g) => g.x == touched ? tooltipBg : Colors.transparent,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final item = data[groupIndex];
                if (touched == null) {
                  // value label on top of every non-empty bar
                  if (item.totalOrders <= 0) return null;
                  return BarTooltipItem(
                    '${item.totalOrders}',
                    TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: groupIndex == data.length - 1 ? t.ink(FxTokens.blue) : t.textMuted,
                      fontFeatures: FxTokens.tabular,
                    ),
                  );
                }
                if (groupIndex != touched) return null;
                final pct = (item.completed / (item.totalOrders > 0 ? item.totalOrders : 1) * 100).round();
                return BarTooltipItem(
                  '${_longLabel(item.period)}\n',
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.sp, height: 1.5),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '${widget.totalLabel}: ',
                      style: TextStyle(color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500, fontSize: 11.sp),
                    ),
                    TextSpan(
                      text: '${item.totalOrders} ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.sp,
                        fontFeatures: FxTokens.tabular,
                      ),
                    ),
                    TextSpan(
                      text: 'chuyến\n',
                      style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 10.5.sp),
                    ),
                    TextSpan(
                      text: 'Xong: ${item.completed} ($pct%)',
                      style: TextStyle(
                        color: completedInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.sp,
                        fontFeatures: FxTokens.tabular,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators: const [0],
                barRods: [
                  BarChartRodData(
                    toY: data[i].totalOrders.toDouble(),
                    width: barW,
                    color: (touched == null ? i == data.length - 1 : i == touched)
                        ? FxTokens.blue
                        : FxTokens.blue.withValues(alpha: touched == null ? (t.dark ? 0.55 : 0.42) : 0.25),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(5.r)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: s.hi,
                      color: i == touched ? t.soft(FxTokens.blue) : t.cardAlt.withValues(alpha: t.dark ? 0.7 : 1),
                    ),
                  ),
                ],
              ),
          ],
        ),
        duration: Duration.zero,
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: axisW, child: axis),
          Expanded(
            child: fits
                ? plot
                : SingleChildScrollView(
                    controller: widget.scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: chartW, child: plot),
                  ),
          ),
        ],
      );
    });
  }
}
