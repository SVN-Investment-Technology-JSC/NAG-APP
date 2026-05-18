import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/home/presentation/widgets/home_order_item.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart' as vm;
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/features/stations/data/models/station_model.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';
import 'package:nguyenanh/features/reports/presentation/widgets/metric_card.dart';
import 'package:nguyenanh/features/reports/presentation/widgets/station_detail_modal.dart';

class ProductionView extends StatefulWidget {
  final ProductionReportResponse? report;
  final ProductionReportResponse? prevReport;
  final String groupBy;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;
  final Function(DateTime)? onNavigateTrips;

  const ProductionView({
    super.key,
    this.report,
    this.prevReport,
    required this.groupBy,
    required this.tankerVehicleIds,
    required this.allVehicles,
    this.onNavigateTrips,
  });

  @override
  State<ProductionView> createState() => _ProductionViewState();
}

class _ProductionViewState extends State<ProductionView> {
  late ScrollController _chartScrollController;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _chartScrollController = ScrollController();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(ProductionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report != oldWidget.report) {
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.animateTo(
          _chartScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.report == null) return Center(child: Text(l10n.noData));

    final summary = widget.report!.summary;
    final prevSummary = widget.prevReport?.summary;

    // Calculate actual periods in range
    final fromDate = DateTime.tryParse(widget.report!.from) ?? DateTime.now();
    final toDate = DateTime.tryParse(widget.report!.to) ?? DateTime.now();
    
    int getRangePeriodCount(DateTime start, DateTime end) {
      if (widget.groupBy == 'month') {
        return (end.year - start.year) * 12 + end.month - start.month + 1;
      }
      if (widget.groupBy == 'week') {
        return (end.difference(start).inDays / 7).ceil();
      }
      return end.difference(start).inDays + 1;
    }

    final periodCount = getRangePeriodCount(fromDate, toDate) > 0 ? getRangePeriodCount(fromDate, toDate) : 1;
    final avgProduction = summary.totalOrders / periodCount;

    // Previous period stats
    double prevAvg = 0;
    if (prevSummary != null && widget.prevReport != null) {
      final prevFrom = DateTime.tryParse(widget.prevReport!.from) ?? DateTime.now();
      final prevTo = DateTime.tryParse(widget.prevReport!.to) ?? DateTime.now();
      final prevPeriodCount = getRangePeriodCount(prevFrom, prevTo) > 0 ? getRangePeriodCount(prevFrom, prevTo) : 1;
      prevAvg = prevSummary.totalOrders / prevPeriodCount;
    }

    // Calculate Completion Rate
    final completionRate = summary.totalOrders > 0
        ? (summary.completed / summary.totalOrders * 100).round()
        : 0;
    
    final prevCompletionRate = (prevSummary != null && prevSummary.totalOrders > 0)
        ? (prevSummary.completed / prevSummary.totalOrders * 100).round()
        : 0;

    String deltaPercent(num current, num previous) {
      if (previous == 0) return current > 0 ? '+100%' : '0%';
      final delta = ((current - previous) / previous) * 100;
      final sign = delta >= 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(1)}%';
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric Grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 1.2 : 1.5,
            children: [
              MetricCard(
                label: l10n.avgProduction,
                value: avgProduction.toStringAsFixed(1),
                subValue: deltaPercent(avgProduction, prevAvg),
                icon: Icons.bar_chart_rounded,
                accentColor: Colors.blue,
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
              ),
              MetricCard(
                label: l10n.totalTrips,
                value: '${summary.totalOrders}',
                subValue: deltaPercent(summary.totalOrders, prevSummary?.totalOrders ?? 0),
                icon: Icons.route_rounded,
                accentColor: Colors.purple,
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
              ),
              MetricCard(
                label: l10n.completedUpper,
                value: '$completionRate%',
                subValue: deltaPercent(completionRate, prevCompletionRate),
                icon: Icons.check_circle_outline_rounded,
                accentColor: const Color(0xFF10B981),
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
              ),
              MetricCard(
                label: l10n.totalKm,
                value: summary.totalDistanceKm.round().toLocaleString(),
                subValue: deltaPercent(summary.totalDistanceKm, prevSummary?.totalDistanceKm ?? 0),
                icon: Icons.speed_rounded,
                accentColor: Colors.orange,
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Production Chart
          // Production Chart
          _buildChartSection(context, theme, colorScheme, avgProduction),
          SizedBox(height: 24.h),

          // Station Performance
          _buildStationPerformance(context, theme, colorScheme),
          SizedBox(height: 24.h),

          // Recent Periods
          _buildRecentPeriods(context, theme, colorScheme),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildRecentPeriods(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final series = widget.report?.series ?? [];
    final displaySeries = series.reversed.take(4).toList();
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.productionRecent,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${series.length} ${widget.groupBy == 'day' ? l10n.dayUpper.toLowerCase() : l10n.periodUpper.toLowerCase()}',
                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Text(
            l10n.clickToOpenDetails,
            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
          SizedBox(height: 24.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displaySeries.length,
            separatorBuilder: (_, __) => Divider(height: 32.h, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (context, index) {
              return _buildPeriodItem(context, displaySeries[index], theme, colorScheme);
            },
          ),
          if (series.length > 4) ...[
            Divider(height: 32.h, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _ProductionHistoryPage(
                        series: series.reversed.toList(),
                        groupBy: widget.groupBy,
                        tankerVehicleIds: widget.tankerVehicleIds,
                        allVehicles: widget.allVehicles,
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.keyboard_arrow_right_rounded, size: 20.sp),
                label: Text('${l10n.seeAll} ${series.length} ${l10n.periodUpper.toLowerCase()}'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodItem(BuildContext context, ProductionSeriesItem item, ThemeData theme, ColorScheme colorScheme) {
    final date = DateTime.tryParse(item.period);
    final dayStr = date != null ? DateFormat('dd').format(date) : '';
    final fullDateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : item.period;
    final percent = item.totalOrders > 0 ? (item.completed / item.totalOrders * 100).round() : 0;
    
    return InkWell(
      onTap: () => _showTripDetailModal(context, date, fullDateStr),
      child: Row(
        children: [
          // Date Icon
          Container(
            width: 52.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.dayUpper,
                  style: TextStyle(
                    fontSize: 8.sp,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  dayStr,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullDateStr,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4.w,
                  runSpacing: 2.h,
                  children: [
                    Text(
                      '${item.completed}/${item.totalOrders} ${l10n.completedStatus}',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle),
                    ),
                    Text(
                      '${item.distanceKm.toInt().toLocaleString()} km',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Progress & Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.totalOrders.toString(),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    l10n.trips,
                    style: TextStyle(fontSize: 10.sp, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              SizedBox(
                width: 80.w,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 4.h,
                    backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percent < 50 ? Colors.red : percent < 100 ? Colors.orange : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 11.sp, 
                  fontWeight: FontWeight.w900, 
                  color: percent < 50 ? Colors.red : percent < 100 ? Colors.orange : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          SizedBox(width: 8.w),
          Icon(Icons.chevron_right, size: 18.sp, color: colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, ThemeData theme, ColorScheme colorScheme, double avgProduction) {
    final chartData = widget.report?.series ?? []; // Use all data, no longer sublisting to 7
    
    double maxYValue = 10;
    for (var item in chartData) {
      if (item.totalOrders > maxYValue) maxYValue = item.totalOrders.toDouble();
    }
    maxYValue = (maxYValue * 1.3).ceilToDouble();

    // Calculate dynamic width: If more than 7 bars, make it scrollable
    final double barWidth = 48.w; 
    final double minChartWidth = chartData.length > 7 ? chartData.length * barWidth : MediaQuery.of(context).size.width - 72.w;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.productionChart,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    l10n.productionChartDesc(widget.groupBy == 'day' ? l10n.byDay.toLowerCase() : widget.groupBy == 'week' ? l10n.byWeek.toLowerCase() : l10n.byMonth.toLowerCase()),
                    style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.more_horiz_rounded, color: colorScheme.onSurfaceVariant),
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: 32.h),
          SizedBox(
            height: 220.h,
            child: Row(
              children: [
                // FIXED LEFT AXIS
                SizedBox(
                  width: 44.w,
                  child: BarChart(
                    BarChartData(
                      maxY: maxYValue,
                      minY: 0,
                      alignment: BarChartAlignment.spaceAround,
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40.w,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max) return const SizedBox.shrink();
                              return Padding(
                                padding: EdgeInsets.only(right: 8.w),
                                child: Text(
                                  value.toInt().toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 9.sp,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        // Align bottom baseline with right side
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32.h,
                            getTitlesWidget: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxYValue / 4).clamp(1, double.infinity),
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [],
                    ),
                  ),
                ),
                // SCROLLABLE CONTENT
                Expanded(
                  child: SingleChildScrollView(
                    controller: _chartScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minChartWidth > 0 ? minChartWidth : MediaQuery.of(context).size.width - 100.w,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxYValue,
                          minY: 0,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              tooltipRoundedRadius: 12.r,
                              tooltipPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              tooltipMargin: 8,
                              getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                final item = chartData[groupIndex];
                                return BarTooltipItem(
                                  '${item.period}\n',
                                  TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13.sp),
                                  children: [
                                    TextSpan(
                                      text: '${l10n.totalProduction}: ',
                                      style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500, fontSize: 11.sp),
                                    ),
                                    TextSpan(
                                      text: '${item.totalOrders} ',
                                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12.sp),
                                    ),
                                    TextSpan(
                                      text: 'chuyến\n',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10.sp),
                                    ),
                                    TextSpan(
                                      text: 'Xong: ${item.completed} (${(item.completed / (item.totalOrders > 0 ? item.totalOrders : 1) * 100).round()}%)',
                                      style: TextStyle(color: const Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 11.sp),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 32.h,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                                    final dateStr = chartData[value.toInt()].period;
                                    final date = DateTime.tryParse(dateStr);
                                    final label = date != null ? DateFormat('dd/MM').format(date) : dateStr;
                                    
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8.h),
                                      child: Text(
                                        label,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: (maxYValue / 4).clamp(1, double.infinity),
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          extraLinesData: ExtraLinesData(
                            horizontalLines: [
                              HorizontalLine(
                                y: avgProduction,
                                color: colorScheme.secondary.withValues(alpha: 0.4),
                                strokeWidth: 1.5,
                                dashArray: [10, 5],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topRight,
                                  padding: EdgeInsets.only(right: 5.w, bottom: 2.h),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.secondary.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.sp,
                                  ),
                                  labelResolver: (line) => 'AVG: ${avgProduction.toStringAsFixed(1)}',
                                ),
                              ),
                            ],
                          ),
                          barGroups: List.generate(chartData.length, (index) {
                            final item = chartData[index];
                            final isLast = index == chartData.length - 1;
                            return _makeGroupData(
                              index, 
                              item.totalOrders.toDouble(), 
                              isLast 
                                ? colorScheme.primary 
                                : colorScheme.primary.withValues(alpha: 0.25), 
                              maxYValue,
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              _buildLegendItem(colorScheme.primary, l10n.totalProduction, theme),
              SizedBox(width: 16.w),
              _buildLegendItem(colorScheme.secondary.withValues(alpha: 0.4), l10n.averageLevel, theme, isDash: true),
              const Spacer(),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.detailsUpper,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, ThemeData theme, {bool isDash = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 3.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }

  BarChartGroupData _makeGroupData(int x, double y, Color color, double maxY) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.7),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
          width: 16.w,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: color.withValues(alpha: 0.03),
          ),
        ),
      ],
    );
  }

  Widget _buildStationPerformance(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final topStations = widget.report?.topStations ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.stationPerformance,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              l10n.seeAll,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        if (topStations.isEmpty)
          Center(child: Text(l10n.noStationData, style: theme.textTheme.bodySmall))
        else
          ...topStations.take(5).map((station) => _buildStationCard(context, theme, colorScheme, station)),
      ],
    );
  }

  Widget _buildStationCard(BuildContext context, ThemeData theme, ColorScheme colorScheme, ProductionTopStation station) {
    // Calculate a mock percentage for display based on total orders
    final totalOrders = widget.report?.summary.totalOrders ?? 1;
    final percent = (station.totalOrders / totalOrders * 100).clamp(10, 100).round();

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: InkWell(
        onTap: () {
          if (widget.report == null) return;
          final from = DateTime.tryParse(widget.report!.from) ?? DateTime.now();
          final to = DateTime.tryParse(widget.report!.to) ?? DateTime.now();
          
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => StationDetailModal(
              station: station,
              from: from,
              to: to,
              tankerVehicleIds: widget.tankerVehicleIds,
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              _buildCircularProgress(percent, colorScheme.primary),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.stationName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${station.totalOrders} ${l10n.trips}',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularProgress(int percent, Color color) {
    return SizedBox(
      width: 44.w,
      height: 44.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 4.w,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text(
            '$percent%',
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  void _showTripDetailModal(BuildContext context, DateTime? date, String fullDateStr) {
    if (date == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TripDetailModal(
        date: date,
        fullDateStr: fullDateStr,
        tankerVehicleIds: widget.tankerVehicleIds,
        allVehicles: widget.allVehicles,
      ),
    );
  }
}

class _TripDetailModal extends StatefulWidget {
  final DateTime date;
  final String fullDateStr;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;

  const _TripDetailModal({
    required this.date,
    required this.fullDateStr,
    required this.tankerVehicleIds,
    required this.allVehicles,
  });

  @override
  State<_TripDetailModal> createState() => _TripDetailModalState();
}

class _TripDetailModalState extends State<_TripDetailModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        child: Column(
          children: [
            // Header Section (Dark Blue Background like React)
            Container(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 12.w, 20.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1E40AF), // Dark blue
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.tripDetail} — ${widget.fullDateStr}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18.sp,
                              ),
                            ),
                            FutureBuilder<List<OrderModel>>(
                              future: OrderService(ApiClient.dio).getOrdersByDate(DateFormat('yyyy-MM-dd').format(widget.date)),
                              builder: (context, snapshot) {
                                final count = snapshot.data?.where((o) => 
                                  o.vehicles != null && widget.tankerVehicleIds.contains(o.vehicles!.vehicleId)
                                ).length ?? 0;
                                return Text(
                                  l10n.tripsInPeriod(count),
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.sp),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  // Summary Cards
                  FutureBuilder<List<OrderModel>>(
                    future: OrderService(ApiClient.dio).getOrdersByDate(DateFormat('yyyy-MM-dd').format(widget.date)),
                    builder: (context, snapshot) {
                      final orders = snapshot.data?.where((o) => 
                        o.vehicles != null && widget.tankerVehicleIds.contains(o.vehicles!.vehicleId)
                      ).toList() ?? [];
                      
                      final total = orders.length;
                      final completed = orders.where((o) => o.orderStatus == 'completed').length;
                      final processing = orders.where((o) => o.orderStatus == 'transporting' || o.orderStatus == 'collecting').length;
                      final totalKm = orders.fold<double>(0, (sum, o) => sum + (o.orderMulti?.distanceKm ?? 0));

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSummaryBox(l10n.totalTrips, total.toString(), Colors.white.withValues(alpha: 0.1)),
                            SizedBox(width: 12.w),
                            _buildSummaryBox(l10n.completedUpper, completed.toString(), Colors.white.withValues(alpha: 0.1), textColor: const Color(0xFF4ADE80)),
                            SizedBox(width: 12.w),
                            _buildSummaryBox(l10n.pendingOrders, processing.toString(), Colors.white.withValues(alpha: 0.1), textColor: const Color(0xFFFBBF24)),
                            SizedBox(width: 12.w),
                            _buildSummaryBox(l10n.totalKm, totalKm.toStringAsFixed(0), Colors.white.withValues(alpha: 0.1)),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: colorScheme.primary, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: l10n.searchVehicleHint,
                          hintStyle: TextStyle(fontSize: 14.sp, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content List
            Expanded(
              child: FutureBuilder<List<OrderModel>>(
                future: OrderService(ApiClient.dio).getOrdersByDate(DateFormat('yyyy-MM-dd').format(widget.date)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final allOrders = snapshot.data ?? [];
                  final filteredOrders = allOrders.where((o) {
                    final isTanker = o.vehicles != null && widget.tankerVehicleIds.contains(o.vehicles!.vehicleId);
                    if (!isTanker) return false;
                    
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    final plate = o.vehicles?.vehicleLicensePlate.toLowerCase() ?? '';
                    final vId = o.vehicles?.vehicleId.toString() ?? '';
                    // Try to find name from allVehicles
                    final name = widget.allVehicles.firstWhere((vm.VehicleModel v) => v.vehicleId == o.vehicles?.vehicleId, orElse: () => vm.VehicleModel(vehicleId: 0, vehicleName: '', vehicleLicensePlate: '', vehicleStatus: '', vehicleTypeId: 0)).vehicleName.toLowerCase();
                    
                    return plate.contains(query) || vId.contains(query) || name.contains(query);
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 48.sp, color: colorScheme.outlineVariant),
                          SizedBox(height: 16.h),
                          Text(l10n.noTripsFound),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 40.h),
                    itemCount: filteredOrders.length,
                    separatorBuilder: (_, __) => Divider(height: 1.h, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final vehicle = widget.allVehicles.firstWhere(
                        (vm.VehicleModel v) => v.vehicleId == order.vehicles?.vehicleId,
                        orElse: () => vm.VehicleModel(vehicleId: 0, vehicleName: 'Unknown', vehicleLicensePlate: '---', vehicleStatus: '', vehicleTypeId: 0),
                      );
                      return _DetailTripItem(index: index + 1, order: order, vehicle: vehicle);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, String value, Color bgColor, {Color textColor = Colors.white}) {
    return Container(
      width: 110.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.sp, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(color: textColor, fontSize: 20.sp, fontWeight: FontWeight.w900),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DetailTripItem extends StatelessWidget {
  final int index;
  final OrderModel order;
  final vm.VehicleModel vehicle;

  const _DetailTripItem({required this.index, required this.order, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(order.orderStatus);
    final statusText = _getStatusText(order.orderStatus, l10n);

    final isCompleted = order.orderStatus == 'completed';
    final distance = isCompleted ? (order.orderMulti?.distanceKm ?? 0) : 0.0;
    final stops = isCompleted ? (order.orderMulti?.stopCount ?? 0) : 0;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // STT
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      index.toString(),
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Vehicle Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.vehicleName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 15.sp),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        order.vehicles?.vehicleLicensePlate ?? '---',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 10.sp),
                  ),
                ),
                SizedBox(width: 12.w),
                // Station
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TRẠM',
                        style: TextStyle(fontSize: 7.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        order.stations?.stationName ?? '---',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 12.sp),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Info Row
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  _buildDetailCol(context, 'KM', distance.toStringAsFixed(0), isAccent: true),
                  _buildDetailDivider(context),
                  _buildDetailCol(context, 'DỪNG', stops.toString()),
                  _buildDetailDivider(context),
                  _buildTimeCol(context, 'BẮT ĐẦU', order.orderStartDatetime),
                  _buildDetailDivider(context),
                  _buildTimeCol(context, 'KẾT THÚC', order.orderEndDatetime),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailDivider(BuildContext context) {
    return Container(
      height: 20.h,
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
    );
  }

  Widget _buildDetailCol(BuildContext context, String label, String value, {bool isAccent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp, 
              fontWeight: FontWeight.w900, 
              color: isAccent ? const Color(0xFF2563EB) : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCol(BuildContext context, String label, String? isoTime) {
    String time = '--:--';
    if (isoTime != null) {
      final dt = DateTime.tryParse(isoTime)?.toLocal();
      if (dt != null) {
        time = DateFormat('HH:mm').format(dt);
      }
    }
    return Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 8.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          SizedBox(height: 2.h),
          Text(time, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF10B981);
      case 'transporting': return const Color(0xFF3B82F6);
      case 'collecting': 
      case 'running': return const Color(0xFFF59E0B);
      case 'init': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'completed': return l10n.completedStatus;
      case 'transporting': return l10n.transportingStatus;
      case 'collecting': 
      case 'running': return l10n.running;
      case 'init': return l10n.initStatus;
      default: return l10n.otherStatus;
    }
  }
}

class _ProductionHistoryPage extends StatelessWidget {
  final List<ProductionSeriesItem> series;
  final String groupBy;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;

  const _ProductionHistoryPage({
    required this.series,
    required this.groupBy,
    required this.tankerVehicleIds,
    required this.allVehicles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(
          l10n.productionChart,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(20.w),
        itemCount: series.length,
        separatorBuilder: (_, __) => SizedBox(height: 16.h),
        itemBuilder: (context, index) {
          final item = series[index];
          // We need to wrap it in a container to match the styling of the main page
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: _ProductionHistoryItem(
              item: item,
              groupBy: groupBy,
              tankerVehicleIds: tankerVehicleIds,
              allVehicles: allVehicles,
            ),
          );
        },
      ),
    );
  }
}

class _ProductionHistoryItem extends StatelessWidget {
  final ProductionSeriesItem item;
  final String groupBy;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;

  const _ProductionHistoryItem({
    required this.item,
    required this.groupBy,
    required this.tankerVehicleIds,
    required this.allVehicles,
  });

  void _showTripDetailModal(BuildContext context, DateTime? date, String fullDateStr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TripDetailModal(
        date: date!,
        fullDateStr: fullDateStr,
        tankerVehicleIds: tankerVehicleIds,
        allVehicles: allVehicles,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final date = DateTime.tryParse(item.period);
    final dayStr = date != null ? DateFormat('dd').format(date) : '';
    final fullDateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : item.period;
    final percent = item.totalOrders > 0 ? (item.completed / item.totalOrders * 100).round() : 0;
    
    return InkWell(
      onTap: () => _showTripDetailModal(context, date, fullDateStr),
      child: Row(
        children: [
          // Date Icon
          Container(
            width: 52.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  groupBy == 'day' ? l10n.dayUpper : l10n.periodUpper,
                  style: TextStyle(fontSize: 8.sp, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  dayStr,
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900, color: colorScheme.primary),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullDateStr,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                // Using Wrap instead of Row to prevent overflow
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6.w,
                  runSpacing: 2.h,
                  children: [
                    Text(
                      '${item.completed}/${item.totalOrders} ${l10n.completedStatus}',
                      style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(color: colorScheme.outlineVariant, shape: BoxShape.circle),
                    ),
                    Text(
                      '${item.distanceKm.toStringAsFixed(0)} km',
                      style: TextStyle(fontSize: 11.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Progress
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    item.totalOrders.toString(),
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    l10n.trips,
                    style: TextStyle(fontSize: 9.sp, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              _buildSimpleProgress(percent, _getProgressColor(percent)),
              Text(
                '$percent%',
                style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w900, color: _getProgressColor(percent)),
              ),
            ],
          ),
          SizedBox(width: 4.w),
          Icon(Icons.chevron_right_rounded, color: colorScheme.outlineVariant, size: 18.sp),
        ],
      ),
    );
  }

  Widget _buildSimpleProgress(int percent, Color color) {
    return Container(
      width: 60.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: percent / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3.r),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(int percent) {
    if (percent >= 100) return const Color(0xFF10B981);
    if (percent >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

extension on num {
  String toLocaleString() {
    return NumberFormat('#,###', 'vi_VN').format(this);
  }
}
