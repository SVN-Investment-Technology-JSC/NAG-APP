import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/features/reports/data/models/report_model.dart';
import 'package:nguyenanh/features/reports/presentation/v2/report_charts_v2.dart';
import 'package:nguyenanh/features/reports/presentation/v2/station_detail_modal_v2.dart';
import 'package:nguyenanh/features/vehicle/data/models/vehicle_model.dart' as vm;
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Sản lượng" tab (v2). Same inputs and the same figures as v1 [ProductionView]; only the presentation changed.
class ProductionViewV2 extends StatefulWidget {
  final ProductionReportResponse? report;
  final ProductionReportResponse? prevReport;
  final String groupBy;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;
  final Function(DateTime)? onNavigateTrips;

  /// Shown as "Thử lại" on the empty state when the report could not be loaded.
  final VoidCallback? onRetry;

  const ProductionViewV2({
    super.key,
    this.report,
    this.prevReport,
    required this.groupBy,
    required this.tankerVehicleIds,
    required this.allVehicles,
    this.onNavigateTrips,
    this.onRetry,
  });

  @override
  State<ProductionViewV2> createState() => _ProductionViewV2State();
}

class _ProductionViewV2State extends State<ProductionViewV2> {
  static const _stationsPerPage = 5;

  late ScrollController _chartScrollController;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // presentation state
  int _stationPage = 0;

  @override
  void initState() {
    super.initState();
    _chartScrollController = ScrollController();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(ProductionViewV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.report != oldWidget.report) {
      _stationPage = 0;
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
    final t = FxTokens.of(context);

    if (widget.report == null) {
      return ListView(
        padding: EdgeInsets.all(14.w),
        children: [
          SizedBox(height: 40.h),
          FxEmpty(
            icon: Icons.insert_chart_outlined_rounded,
            title: l10n.noData,
            action: widget.onRetry == null
                ? null
                : FilledButton.tonalIcon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.retry),
                  ),
          ),
        ],
      );
    }

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
    final completionRate = summary.totalOrders > 0 ? (summary.completed / summary.totalOrders * 100).round() : 0;

    final prevCompletionRate = (prevSummary != null && prevSummary.totalOrders > 0)
        ? (prevSummary.completed / prevSummary.totalOrders * 100).round()
        : 0;

    String deltaPercent(num current, num previous) {
      if (previous == 0) return current > 0 ? '+100%' : '0%';
      final delta = ((current - previous) / previous) * 100;
      final sign = delta >= 0 ? '+' : '';
      return '$sign${delta.toStringAsFixed(1)}%';
    }

    final wide = MediaQuery.of(context).size.width > 600;

    return ListView(
      padding: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 28.h),
      children: [
        FxGrid(
          columns: wide ? 4 : 2,
          children: [
            FxKpi(
              icon: Icons.bar_chart_rounded,
              label: l10n.avgProduction,
              value: avgProduction.toStringAsFixed(1),
              unit: l10n.trips,
              tone: FxTokens.blue,
              footer: _deltaFooter(t, deltaPercent(avgProduction, prevAvg)),
            ),
            FxKpi(
              icon: Icons.route_rounded,
              label: l10n.totalTrips,
              value: '${summary.totalOrders}',
              unit: l10n.trips,
              tone: FxTokens.violet,
              footer: _deltaFooter(t, deltaPercent(summary.totalOrders, prevSummary?.totalOrders ?? 0)),
            ),
            FxKpi(
              icon: Icons.check_circle_outline_rounded,
              label: l10n.completedUpper,
              value: '$completionRate%',
              tone: FxTokens.emerald,
              footer: _deltaFooter(t, deltaPercent(completionRate, prevCompletionRate)),
            ),
            FxKpi(
              icon: Icons.speed_rounded,
              label: l10n.totalKm,
              value: summary.totalDistanceKm.round().toLocaleString(),
              unit: 'km',
              tone: FxTokens.orange,
              footer: _deltaFooter(t, deltaPercent(summary.totalDistanceKm, prevSummary?.totalDistanceKm ?? 0)),
            ),
          ],
        ),

        // Production Chart
        _buildChartSection(t, avgProduction),

        // Station Performance
        _buildStationPerformance(t),

        // Recent Periods
        _buildRecentPeriods(t),
      ],
    );
  }

  /// "+12.5%" pill (green up / red down, as v1) + "so với kỳ trước".
  Widget _deltaFooter(FxTokens t, String delta) {
    final down = delta.startsWith('-');
    final up = delta.startsWith('+');
    final tone = down ? FxTokens.red : (up ? FxTokens.emerald : FxTokens.slate);
    return Row(
      children: [
        FxPill(
          icon: down ? Icons.trending_down_rounded : (up ? Icons.trending_up_rounded : Icons.trending_flat_rounded),
          label: delta,
          tone: tone,
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Text('so với kỳ trước', style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── Chart ────────────────────────────────────────────────────────────────

  Widget _buildChartSection(FxTokens t, double avgProduction) {
    final chartData = widget.report?.series ?? []; // all periods
    final groupLabel = widget.groupBy == 'day'
        ? l10n.byDay
        : widget.groupBy == 'week'
            ? l10n.byWeek
            : l10n.byMonth;

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.bar_chart_rounded,
            title: l10n.productionChart,
            // v1 used productionChartDesc(byDay), which reads "… theo theo ngày"; show the same facts without the repeat.
            subtitle: '${l10n.totalProduction} · $groupLabel',
            tone: FxTokens.blue,
          ),
          if (chartData.isEmpty)
            FxEmpty(icon: Icons.bar_chart_rounded, title: l10n.noData)
          else ...[
            SizedBox(height: 4.h),
            SizedBox(
              height: 230.h,
              child: ProductionBarChartV2(
                series: chartData,
                average: avgProduction,
                scrollController: _chartScrollController,
                totalLabel: l10n.totalProduction,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 14.w,
              runSpacing: 6.h,
              children: [
                FxLegend(color: FxTokens.blue, label: l10n.totalProduction),
                FxLegend(
                  color: FxTokens.violet,
                  label: l10n.averageLevel,
                  value: avgProduction.toStringAsFixed(1),
                  line: true,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.touch_app_outlined, size: 13.sp, color: t.textFaint),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    'Chạm vào cột để xem chi tiết',
                    style: t.tiny.copyWith(color: t.textFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Stations ─────────────────────────────────────────────────────────────

  Widget _buildStationPerformance(FxTokens t) {
    final topStations = widget.report?.topStations ?? [];
    final page = fxPage(topStations, _stationPage, _stationsPerPage);

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.local_gas_station_rounded,
            title: l10n.stationPerformance,
            subtitle: topStations.isEmpty ? null : 'Chạm vào trạm để xem chi tiết',
            tone: FxTokens.emerald,
            trailing: topStations.isEmpty ? null : FxPill(label: '${topStations.length}', tone: FxTokens.emerald),
          ),
          if (topStations.isEmpty)
            FxEmpty(icon: Icons.local_gas_station_outlined, title: l10n.noStationData)
          else ...[
            for (final station in page) _buildStationCard(t, station),
            FxPager(
              page: _stationPage,
              total: topStations.length,
              size: _stationsPerPage,
              onChanged: (p) => setState(() => _stationPage = p),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStationCard(FxTokens t, ProductionTopStation station) {
    // Same display percentage as v1 (share of total trips, clamped to 10–100)
    final totalOrders = widget.report?.summary.totalOrders ?? 1;
    final percent = (station.totalOrders / totalOrders * 100).clamp(10, 100).round();

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.r),
          onTap: () {
            if (widget.report == null) return;
            final from = DateTime.tryParse(widget.report!.from) ?? DateTime.now();
            final to = DateTime.tryParse(widget.report!.to) ?? DateTime.now();

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => StationDetailModalV2(
                station: station,
                from: from,
                to: to,
                tankerVehicleIds: widget.tankerVehicleIds,
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                FxGauge(
                  value: percent.toDouble(),
                  size: 44.w,
                  stroke: 4.5,
                  color: FxTokens.emerald,
                  center: Text('$percent%', style: t.num(10.sp)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(station.stationName, style: t.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 2.h),
                      Text(
                        '${station.totalOrders} ${l10n.trips}',
                        style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textFaint, size: 20.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Recent periods ───────────────────────────────────────────────────────

  Widget _buildRecentPeriods(FxTokens t) {
    final series = widget.report?.series ?? [];
    final displaySeries = series.reversed.take(4).toList();

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.history_rounded,
            title: l10n.productionRecent,
            subtitle: l10n.clickToOpenDetails,
            tone: FxTokens.indigo,
            trailing: FxPill(
              label:
                  '${series.length} ${widget.groupBy == 'day' ? l10n.dayUpper.toLowerCase() : l10n.periodUpper.toLowerCase()}',
              tone: FxTokens.slate,
            ),
          ),
          if (displaySeries.isEmpty)
            FxEmpty(icon: Icons.event_busy_rounded, title: l10n.noData)
          else
            for (var i = 0; i < displaySeries.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
              _PeriodRowV2(
                item: displaySeries[i],
                badgeLabel: l10n.dayUpper,
                kmText: '${displaySeries[i].distanceKm.toInt().toLocaleString()} km',
                onTap: (date, fullDateStr) => _showTripDetailModal(context, date, fullDateStr),
              ),
            ],
          if (series.length > 4) ...[
            SizedBox(height: 10.h),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _ProductionHistoryPageV2(
                      series: series.reversed.toList(),
                      groupBy: widget.groupBy,
                      tankerVehicleIds: widget.tankerVehicleIds,
                      allVehicles: widget.allVehicles,
                    ),
                  ),
                );
              },
              iconAlignment: IconAlignment.end,
              icon: Icon(Icons.arrow_forward_rounded, size: 16.sp),
              label: Text(
                '${l10n.seeAll} ${series.length} ${l10n.periodUpper.toLowerCase()}',
                style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                backgroundColor: t.soft(FxTokens.blue),
                foregroundColor: t.ink(FxTokens.blue),
                minimumSize: Size.fromHeight(40.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showTripDetailModal(BuildContext context, DateTime? date, String fullDateStr) {
    if (date == null) return;
    _openTripDetail(context, date, fullDateStr, widget.tankerVehicleIds, widget.allVehicles);
  }
}

void _openTripDetail(
  BuildContext context,
  DateTime date,
  String fullDateStr,
  Set<int> tankerVehicleIds,
  List<vm.VehicleModel> allVehicles,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TripDetailModalV2(
      date: date,
      fullDateStr: fullDateStr,
      tankerVehicleIds: tankerVehicleIds,
      allVehicles: allVehicles,
    ),
  );
}

// ─── Period row (recent list + history page) ────────────────────────────────

class _PeriodRowV2 extends StatelessWidget {
  final ProductionSeriesItem item;
  final String badgeLabel;
  final String kmText;
  final void Function(DateTime? date, String fullDateStr) onTap;

  const _PeriodRowV2({required this.item, required this.badgeLabel, required this.kmText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final date = DateTime.tryParse(item.period);
    final dayStr = date != null ? DateFormat('dd').format(date) : '';
    final fullDateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : item.period;
    final percent = item.totalOrders > 0 ? (item.completed / item.totalOrders * 100).round() : 0;
    final pColor = percent < 50
        ? FxTokens.red
        : percent < 100
            ? FxTokens.amber
            : FxTokens.emerald;

    return InkWell(
      onTap: () => onTap(date, fullDateStr),
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 46.w,
              height: 50.h,
              decoration: BoxDecoration(
                color: t.soft(FxTokens.blue),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    badgeLabel,
                    style: t.overline.copyWith(fontSize: 8.sp, color: t.ink(FxTokens.blue).withValues(alpha: 0.75)),
                    maxLines: 1,
                  ),
                  SizedBox(height: 1.h),
                  dayStr.isEmpty
                      ? Icon(Icons.date_range_rounded, size: 18.sp, color: t.ink(FxTokens.blue))
                      : Text(dayStr, style: t.num(18.sp, color: t.ink(FxTokens.blue))),
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
                    style: t.h3.copyWith(fontFeatures: FxTokens.tabular),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${item.completed}/${item.totalOrders} ${l10n.completedStatus} · $kmText',
                    style: t.tiny.copyWith(fontFeatures: FxTokens.tabular),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            // Total & completion
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: item.totalOrders.toString(), style: t.num(16.sp)),
                  TextSpan(text: ' ${l10n.trips}', style: t.tiny),
                ])),
                SizedBox(height: 6.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48.w,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent / 100,
                          minHeight: 4,
                          backgroundColor: t.track,
                          color: pColor,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 36.w,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.right,
                        style: t.tiny.copyWith(
                          color: t.ink(pColor),
                          fontWeight: FontWeight.w800,
                          fontFeatures: FxTokens.tabular,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(width: 4.w),
            Icon(Icons.chevron_right_rounded, size: 18.sp, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}

// ─── Trip detail sheet ──────────────────────────────────────────────────────

class _TripDetailModalV2 extends StatefulWidget {
  final DateTime date;
  final String fullDateStr;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;

  const _TripDetailModalV2({
    required this.date,
    required this.fullDateStr,
    required this.tankerVehicleIds,
    required this.allVehicles,
  });

  @override
  State<_TripDetailModalV2> createState() => _TripDetailModalV2State();
}

class _TripDetailModalV2State extends State<_TripDetailModalV2> {
  static const _perPage = 8;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Same request as v1 (orders of that day), made once per sheet instead of on every rebuild.
  late Future<List<OrderModel>> _ordersFuture = _fetchOrders();
  int _page = 0;

  Future<List<OrderModel>> _fetchOrders() =>
      OrderService(ApiClient.dio).getOrdersByDate(DateFormat('yyyy-MM-dd').format(widget.date));

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<List<OrderModel>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            final waiting = snapshot.connectionState == ConnectionState.waiting;

            // Header figures (same as v1)
            final orders = snapshot.data
                    ?.where((o) => o.vehicles != null && widget.tankerVehicleIds.contains(o.vehicles!.vehicleId))
                    .toList() ??
                [];
            final total = orders.length;
            final completed = orders.where((o) => o.orderStatus == 'completed').length;
            final processing =
                orders.where((o) => o.orderStatus == 'transporting' || o.orderStatus == 'collecting').length;
            final totalKm = orders.fold<double>(0, (sum, o) => sum + (o.orderMulti?.distanceKm ?? 0));

            // List (same filter as v1)
            final allOrders = snapshot.data ?? [];
            final filteredOrders = allOrders.where((o) {
              final isTanker = o.vehicles != null && widget.tankerVehicleIds.contains(o.vehicles!.vehicleId);
              if (!isTanker) return false;

              if (_searchQuery.isEmpty) return true;
              final query = _searchQuery.toLowerCase();
              final plate = o.vehicles?.vehicleLicensePlate.toLowerCase() ?? '';
              final vId = o.vehicles?.vehicleId.toString() ?? '';
              // Try to find name from allVehicles
              final name = widget.allVehicles
                  .firstWhere(
                    (vm.VehicleModel v) => v.vehicleId == o.vehicles?.vehicleId,
                    orElse: () => vm.VehicleModel(
                      vehicleId: 0,
                      vehicleName: '',
                      vehicleLicensePlate: '',
                      vehicleStatus: '',
                      vehicleTypeId: 0,
                    ),
                  )
                  .vehicleName
                  .toLowerCase();

              return plate.contains(query) || vId.contains(query) || name.contains(query);
            }).toList();

            final pages = (filteredOrders.length / _perPage).ceil();
            final pageIndex = pages == 0 ? 0 : _page.clamp(0, pages - 1).toInt();
            final pageItems = fxPage(filteredOrders, pageIndex, _perPage);

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(t, l10n, waiting, total, completed, processing, totalKm),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                    child: FxSearchField(
                      hint: l10n.searchVehicleHint,
                      controller: _searchController,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _page = 0;
                      }),
                    ),
                  ),
                ),
                if (waiting)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    sliver: SliverList.list(
                      children: [
                        for (var i = 0; i < 4; i++) ...[
                          FxSkeleton(height: 132.h, radius: 14),
                          SizedBox(height: 10.h),
                        ],
                      ],
                    ),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: FxEmpty(
                        icon: Icons.cloud_off_rounded,
                        title: 'Không tải được danh sách chuyến',
                        action: FilledButton.tonalIcon(
                          onPressed: () => setState(() {
                            _ordersFuture = _fetchOrders();
                            _page = 0;
                          }),
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(l10n.retry),
                        ),
                      ),
                    ),
                  )
                else if (filteredOrders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: FxEmpty(icon: Icons.local_shipping_outlined, title: l10n.noTripsFound),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 40.h),
                    sliver: SliverList.list(
                      children: [
                        for (var i = 0; i < pageItems.length; i++)
                          _DetailTripItemV2(
                            index: pageIndex * _perPage + i + 1,
                            order: pageItems[i],
                            vehicle: widget.allVehicles.firstWhere(
                              (vm.VehicleModel v) => v.vehicleId == pageItems[i].vehicles?.vehicleId,
                              orElse: () => vm.VehicleModel(
                                vehicleId: 0,
                                vehicleName: 'Unknown',
                                vehicleLicensePlate: '---',
                                vehicleStatus: '',
                                vehicleTypeId: 0,
                              ),
                            ),
                          ),
                        FxPager(
                          page: pageIndex,
                          total: filteredOrders.length,
                          size: _perPage,
                          onChanged: (p) => setState(() => _page = p),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    FxTokens t,
    AppLocalizations l10n,
    bool waiting,
    int total,
    int completed,
    int processing,
    double totalKm,
  ) {
    String v(String s) => waiting ? '—' : s;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 10.w, 2.h),
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(2.r)),
            ),
          ),
          Row(
            children: [
              const FxIconBadge(icon: Icons.receipt_long_rounded, tone: FxTokens.blue, size: 40),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.tripDetail} — ${widget.fullDateStr}',
                      style: t.h2.copyWith(fontFeatures: FxTokens.tabular),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(waiting ? 'Đang tải…' : l10n.tripsInPeriod(total), style: t.small),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: t.text, size: 20.sp),
                style: IconButton.styleFrom(backgroundColor: t.cardAlt, side: BorderSide(color: t.border)),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.only(right: 6.w),
            child: FxGrid(
              columns: 2,
              gap: 8.w,
              children: [
                _summaryTile(t, Icons.local_shipping_outlined, FxTokens.blue, l10n.totalTrips, v(total.toString()), null),
                _summaryTile(t, Icons.check_circle_outline_rounded, FxTokens.emerald, l10n.completedUpper,
                    v(completed.toString()), null),
                _summaryTile(t, Icons.timelapse_rounded, FxTokens.amber, l10n.pendingOrders, v(processing.toString()), null),
                _summaryTile(t, Icons.speed_rounded, FxTokens.violet, l10n.totalKm, v(totalKm.toStringAsFixed(0)), 'km'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(FxTokens t, IconData icon, Color tone, String label, String value, String? unit) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          FxIconBadge(icon: icon, tone: tone, size: 30),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: value, style: t.num(17.sp, color: tone == FxTokens.blue ? t.text : t.ink(tone))),
                    if (unit != null && value != '—') TextSpan(text: ' $unit', style: t.tiny),
                  ])),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTripItemV2 extends StatelessWidget {
  final int index;
  final OrderModel order;
  final vm.VehicleModel vehicle;

  const _DetailTripItemV2({required this.index, required this.order, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _getStatusColor(order.orderStatus);
    final statusText = _getStatusText(order.orderStatus, l10n);

    final isCompleted = order.orderStatus == 'completed';
    final distance = isCompleted ? (order.orderMulti?.distanceKm ?? 0) : 0.0;
    final stops = isCompleted ? (order.orderMulti?.stopCount ?? 0) : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // STT
              Container(
                width: 26.w,
                height: 26.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.cardAlt, shape: BoxShape.circle, border: Border.all(color: t.border)),
                child: Text(
                  index.toString(),
                  style: t.tiny.copyWith(color: t.text, fontWeight: FontWeight.w800, fontFeatures: FxTokens.tabular),
                ),
              ),
              SizedBox(width: 10.w),
              // Vehicle Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.vehicleName,
                      style: t.h3.copyWith(fontSize: 14.5.sp),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      order.vehicles?.vehicleLicensePlate ?? '---',
                      style: t.tiny.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              // Status Badge
              FxPill(label: statusText, tone: statusColor, dot: true),
            ],
          ),
          SizedBox(height: 8.h),
          // Station
          Row(
            children: [
              Icon(Icons.local_gas_station_outlined, size: 13.sp, color: t.textFaint),
              SizedBox(width: 4.w),
              Text('TRẠM', style: t.overline),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  order.stations?.stationName ?? '---',
                  style: t.small.copyWith(color: t.text, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Info Row
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: t.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                _buildDetailCol(t, 'KM', distance.toStringAsFixed(0), isAccent: true),
                _buildDetailDivider(t),
                _buildDetailCol(t, 'DỪNG', stops.toString()),
                _buildDetailDivider(t),
                _buildTimeCol(t, 'BẮT ĐẦU', order.orderStartDatetime),
                _buildDetailDivider(t),
                _buildTimeCol(t, 'KẾT THÚC', order.orderEndDatetime),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider(FxTokens t) {
    return Container(
      height: 26.h,
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      color: t.border,
    );
  }

  Widget _buildDetailCol(FxTokens t, String label, String value, {bool isAccent = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.overline, maxLines: 1),
          SizedBox(height: 3.h),
          Text(value, style: t.num(14.sp, color: isAccent ? t.ink(FxTokens.blue) : t.text), maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildTimeCol(FxTokens t, String label, String? isoTime) {
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
          Text(label, style: t.overline, maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 3.h),
          Text(time, style: t.num(14.sp), maxLines: 1),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return FxTokens.emerald;
      case 'transporting':
        return FxTokens.blue;
      case 'collecting':
      case 'running':
        return FxTokens.amber;
      case 'init':
        return FxTokens.slate;
      default:
        return FxTokens.slate;
    }
  }

  String _getStatusText(String status, AppLocalizations l10n) {
    switch (status) {
      case 'completed':
        return l10n.completedStatus;
      case 'transporting':
        return l10n.transportingStatus;
      case 'collecting':
      case 'running':
        return l10n.running;
      case 'init':
        return l10n.initStatus;
      default:
        return l10n.otherStatus;
    }
  }
}

// ─── Full history page ──────────────────────────────────────────────────────

class _ProductionHistoryPageV2 extends StatefulWidget {
  final List<ProductionSeriesItem> series;
  final String groupBy;
  final Set<int> tankerVehicleIds;
  final List<vm.VehicleModel> allVehicles;

  const _ProductionHistoryPageV2({
    required this.series,
    required this.groupBy,
    required this.tankerVehicleIds,
    required this.allVehicles,
  });

  @override
  State<_ProductionHistoryPageV2> createState() => _ProductionHistoryPageV2State();
}

class _ProductionHistoryPageV2State extends State<_ProductionHistoryPageV2> {
  static const _perPage = 10;
  int _page = 0;

  void _showTripDetailModal(BuildContext context, DateTime? date, String fullDateStr) {
    if (date == null) return;
    _openTripDetail(context, date, fullDateStr, widget.tankerVehicleIds, widget.allVehicles);
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final series = widget.series;
    final page = fxPage(series, _page, _perPage);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: t.text),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.productionChart, style: t.h1.copyWith(fontSize: 19.sp)),
            Text('${series.length} ${l10n.periodUpper.toLowerCase()}', style: t.tiny),
          ],
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 28.h),
        children: [
          FxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxSectionHeader(
                  icon: Icons.history_rounded,
                  title: l10n.productionRecent,
                  subtitle: l10n.clickToOpenDetails,
                  tone: FxTokens.indigo,
                ),
                if (series.isEmpty)
                  FxEmpty(icon: Icons.event_busy_rounded, title: l10n.noData)
                else ...[
                  for (var i = 0; i < page.length; i++) ...[
                    if (i > 0) Divider(height: 1, thickness: 1, color: t.divider),
                    _PeriodRowV2(
                      item: page[i],
                      badgeLabel: widget.groupBy == 'day' ? l10n.dayUpper : l10n.periodUpper,
                      kmText: '${page[i].distanceKm.toStringAsFixed(0)} km',
                      onTap: (date, fullDateStr) => _showTripDetailModal(context, date, fullDateStr),
                    ),
                  ],
                  FxPager(page: _page, total: series.length, size: _perPage, onChanged: (p) => setState(() => _page = p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on num {
  String toLocaleString() {
    return NumberFormat('#,###', 'vi_VN').format(this);
  }
}
