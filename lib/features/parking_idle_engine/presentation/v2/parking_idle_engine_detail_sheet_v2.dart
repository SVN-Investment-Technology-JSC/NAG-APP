import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';
import 'package:nguyenanh/features/parking_idle_engine/presentation/v2/pie_v2_shared.dart';

/// "Chi tiết nổ máy" bottom sheet (v2). Same history loading, date range (today by default), paging
/// (10 per page, server side) and chart data (current page, oldest first) as [ParkingIdleEngineDetailSheet].
class ParkingIdleEngineDetailSheetV2 extends StatefulWidget {
  final ParkingIdleEngineAlert alert;
  final ParkingIdleEngineService apiService;

  const ParkingIdleEngineDetailSheetV2({
    super.key,
    required this.alert,
    required this.apiService,
  });

  static void show(BuildContext context, ParkingIdleEngineAlert alert, ParkingIdleEngineService apiService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParkingIdleEngineDetailSheetV2(alert: alert, apiService: apiService),
    );
  }

  @override
  State<ParkingIdleEngineDetailSheetV2> createState() => _ParkingIdleEngineDetailSheetV2State();
}

class _ParkingIdleEngineDetailSheetV2State extends State<ParkingIdleEngineDetailSheetV2> {
  bool _historyLoading = false;
  ParkingIdleEngineHistoryResponse? _historyData;
  int _historyPage = 1;
  final int _historyLimit = 10;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 0)); // Today start
  DateTime _toDate = DateTime.now(); // Today end

  // presentation only
  bool _historyFailed = false;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Default to starting of today and end of today matching React
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day, 0, 0, 0);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _historyLoading = true;
    });

    try {
      final fromStr = _fromDate.toUtc().toIso8601String();
      final toStr = _toDate.toUtc().toIso8601String();

      final res = await widget.apiService.getHistory(
        vehicleId: widget.alert.vehicleId,
        page: _historyPage,
        limit: _historyLimit,
        from: fromStr,
        to: toStr,
      );

      if (mounted) {
        setState(() {
          _historyData = res;
          _historyLoading = false;
          _historyFailed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
          _historyFailed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải lịch sử nổ máy')),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _fromDate,
        end: _toDate,
      ),
    );

    if (pickedRange != null) {
      setState(() {
        _fromDate = DateTime(pickedRange.start.year, pickedRange.start.month, pickedRange.start.day, 0, 0, 0);
        _toDate = DateTime(pickedRange.end.year, pickedRange.end.month, pickedRange.end.day, 23, 59, 59);
        _historyPage = 1;
      });
      _fetchHistory();
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  String get _rangeLabel {
    final df = DateFormat('dd/MM');
    if (DateUtils.isSameDay(_fromDate, _toDate)) {
      return DateUtils.isSameDay(_fromDate, DateTime.now()) ? 'Hôm nay' : DateFormat('dd/MM/yyyy').format(_fromDate);
    }
    return '${df.format(_fromDate)} – ${df.format(_toDate)}';
  }

  double get _threshold => widget.alert.warningAfterMinutes;

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.88,
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(t),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h + mq.padding.bottom),
              children: [
                _infoTiles(t),
                _chartCard(t),
                _historyCard(t),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(FxTokens t) {
    final a = widget.alert;
    final tone = a.inYard ? (pieToneOf(a) == FxTokens.slate ? FxTokens.indigo : pieToneOf(a)) : FxTokens.slate;
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 8.h, 10.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tone.withValues(alpha: t.dark ? 0.32 : 0.14), t.bg],
        ),
        border: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              FxIconBadge(icon: Icons.power_settings_new_rounded, tone: tone, size: 42),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chi tiết nổ máy', style: t.small),
                    SizedBox(height: 2.h),
                    Text(a.vehicleName, style: t.h1.copyWith(fontSize: 18.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 2.h),
                    Text(
                      a.vehicleLicensePlate,
                      style: t.small.copyWith(fontWeight: FontWeight.w600, fontFeatures: FxTokens.tabular),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: t.text, size: 20.sp),
                style: IconButton.styleFrom(backgroundColor: t.card, side: BorderSide(color: t.border)),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              if (a.inYard) PieWarningPill(warning: a.warningActive),
              PieYardPill(inYard: a.inYard),
              if (a.inYard) PieEnginePill(alert: a),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTiles(FxTokens t) {
    final a = widget.alert;
    final tiles = <Widget>[
      if (a.inYard)
        PieLiveElapsed(
          idleStartedAt: a.idleStartedAt,
          fallbackMinutes: a.elapsedMinutes,
          builder: (context, secs) => FxInfoTile(icon: Icons.timer_outlined, label: 'Đã nổ máy', value: pieFmtElapsed(secs)),
        ),
      FxInfoTile(icon: Icons.play_circle_outline_rounded, label: 'Bắt đầu', value: pieFmtStamp(a.idleStartedAt)),
      FxInfoTile(
        icon: Icons.notifications_active_outlined,
        label: 'Ngưỡng cảnh báo',
        value: _threshold > 0 ? '${pieFmtNum(_threshold, 0)} phút' : '—',
      ),
      FxInfoTile(
        icon: Icons.local_gas_station_outlined,
        label: 'Nhiên liệu ước tính',
        value: '${pieFmtNum(a.estimatedIdleFuelLiters, 1)} L',
      ),
      FxInfoTile(icon: Icons.speed_rounded, label: 'Mức tiêu hao', value: '${pieFmtNum(a.idleLPerHour, 1)} L/giờ'),
      FxInfoTile(icon: Icons.factory_outlined, label: 'Trạm', value: a.stationName.isNotEmpty ? a.stationName : '—'),
    ];
    final place = a.geocoding?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxGrid(columns: 2, children: tiles),
        if (place.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: FxInfoTile(icon: Icons.place_outlined, label: 'Vị trí', value: place),
          ),
      ],
    );
  }

  Widget _chartCard(FxTokens t) {
    final list = _historyData?.items ?? [];
    // Slice and reverse just like React: `historyData.items.slice().reverse()`
    final chartList = list.toList().reversed.toList();
    final thr = _threshold;

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Thời gian nổ máy theo phiên',
            subtitle: '$_rangeLabel · chạm vào cột để xem chi tiết',
            tone: FxTokens.indigo,
          ),
          if (_historyLoading && _historyData == null)
            FxSkeleton(height: 190.h)
          else if (chartList.isEmpty)
            FxEmpty(
              icon: Icons.bar_chart_rounded,
              title: _historyFailed && _historyData == null ? 'Không thể tải dữ liệu' : 'Không có dữ liệu',
            )
          else ...[
            Text('PHÚT', style: t.overline),
            SizedBox(height: 6.h),
            SizedBox(height: 190.h, child: _SessionBars(items: chartList, threshold: thr)),
            SizedBox(height: 10.h),
            Wrap(
              spacing: 14.w,
              runSpacing: 6.h,
              children: [
                const FxLegend(color: FxTokens.indigo, label: 'Dưới ngưỡng'),
                if (thr > 0) const FxLegend(color: FxTokens.red, label: 'Vượt ngưỡng'),
                if (thr > 0) FxLegend(color: FxTokens.red, label: 'Ngưỡng ${pieFmtNum(thr, 0)} phút', line: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyCard(FxTokens t) {
    final data = _historyData;
    final items = data?.items ?? [];

    Widget body;
    if (_historyLoading && data == null) {
      body = Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            FxSkeleton(height: 60.h),
            SizedBox(height: 8.h),
          ],
        ],
      );
    } else if (data == null && _historyFailed) {
      body = FxEmpty(
        icon: Icons.cloud_off_rounded,
        title: 'Không thể tải lịch sử nổ máy',
        action: FilledButton.tonalIcon(
          onPressed: _fetchHistory,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Thử lại'),
        ),
      );
    } else if (items.isEmpty) {
      body = FxEmpty(
        icon: Icons.event_busy_rounded,
        title: 'Không có dữ liệu phiên nổ máy',
        message: 'Thử chọn khoảng ngày khác.',
        action: OutlinedButton.icon(
          onPressed: _selectDateRange,
          icon: Icon(Icons.calendar_today_rounded, size: 16.sp),
          label: const Text('Chọn ngày'),
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) _HistoryRow(item: item, threshold: _threshold),
          FxPager(
            page: _historyPage - 1,
            total: data!.total,
            size: _historyLimit,
            onChanged: (p) {
              setState(() {
                _historyPage = p + 1;
              });
              _fetchHistory();
            },
          ),
        ],
      );
    }

    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FxSectionHeader(
            icon: Icons.history_rounded,
            title: 'Lịch sử các phiên nổ máy',
            subtitle: data != null ? '${data.total} phiên trong khoảng đã chọn' : null,
            tone: FxTokens.violet,
            trailing: _RangeButton(label: _rangeLabel, onTap: _selectDateRange),
          ),
          if (_historyLoading && data != null)
            Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(2)),
            ),
          body,
        ],
      ),
    );
  }
}

class _RangeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _RangeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    return Material(
      color: t.soft(FxTokens.indigo),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 13.sp, color: t.ink(FxTokens.indigo)),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: t.ink(FxTokens.indigo),
                  fontFeatures: FxTokens.tabular,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ParkingIdleEngineHistoryItem item;
  final double threshold;
  const _HistoryRow({required this.item, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final start = DateTime.tryParse(item.idleStartedAt)?.toLocal();
    final end = item.idleEndedAt != null ? DateTime.tryParse(item.idleEndedAt!)?.toLocal() : null;
    final over = threshold > 0 && item.elapsedMinutes >= threshold;
    final tone = over ? FxTokens.red : FxTokens.indigo;

    Widget timeCol(String label, DateTime? d) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: t.overline),
            SizedBox(height: 3.h),
            Text(d != null ? DateFormat('HH:mm').format(d) : '—', style: t.num(14.sp)),
            if (d != null) Text(DateFormat('dd/MM').format(d), style: t.tiny.copyWith(fontSize: 9.5.sp, fontFeatures: FxTokens.tabular)),
          ],
        );

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: t.cardAlt,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: over ? FxTokens.red.withValues(alpha: 0.35) : t.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(4)),
            ),
            SizedBox(width: 10.w),
            Expanded(child: timeCol('BẮT ĐẦU', start)),
            Center(child: Icon(Icons.arrow_forward_rounded, size: 14.sp, color: t.textFaint)),
            SizedBox(width: 10.w),
            Expanded(child: timeCol('KẾT THÚC', end)),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(color: t.soft(tone), borderRadius: BorderRadius.circular(10.r)),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${item.elapsedMinutes.round()}', style: t.num(15.sp, color: t.ink(tone))),
                    TextSpan(
                      text: ' phút',
                      style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: t.ink(tone)),
                    ),
                  ]),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bars of the session durations (minutes): nice Y ticks (all labelled), gridlines on ticks,
/// dashed threshold line, readable time labels and a touch tooltip.
class _SessionBars extends StatelessWidget {
  final List<ParkingIdleEngineHistoryItem> items;
  final double threshold;
  const _SessionBars({required this.items, required this.threshold});

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final maxV = items.map((e) => e.elapsedMinutes).fold<double>(0, math.max);
    final top = math.max(maxV, threshold > 0 ? threshold : 0) * 1.12;
    final s = pieNiceScale(0, math.max(top, 1), ticks: 4);
    final dates = items.map((e) => DateTime.tryParse(e.idleStartedAt)?.toLocal()).toList();
    final days = dates.whereType<DateTime>().map((d) => DateTime(d.year, d.month, d.day)).toSet();
    final multiDay = days.length > 1;
    final every = items.length <= 6 ? 1 : (items.length / 6).ceil();
    final barW = (items.length <= 4 ? 26.0 : (items.length <= 7 ? 20.0 : 14.0)).w;
    final labelStyle = TextStyle(fontSize: 9.5.sp, color: t.textMuted, fontFeatures: FxTokens.tabular, height: 1.15);

    return BarChart(
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
        borderData: FlBorderData(show: true, border: Border(bottom: BorderSide(color: t.border))),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (threshold > 0)
              HorizontalLine(
                y: threshold,
                color: FxTokens.red.withValues(alpha: 0.85),
                strokeWidth: 1.4,
                dashArray: [5, 4],
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34.w,
              interval: s.step,
              getTitlesWidget: (v, meta) => pieOnStep(v, s.step)
                  ? SideTitleWidget(
                      meta: meta,
                      space: 6,
                      child: Text(pieFmtNum(v, s.step < 1 ? 1 : 0), style: labelStyle),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: (multiDay ? 32 : 22).h,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= items.length || i % every != 0) return const SizedBox.shrink();
                final d = dates[i];
                if (d == null) return const SizedBox.shrink();
                final text = multiDay ? '${DateFormat('HH:mm').format(d)}\n${DateFormat('dd/MM').format(d)}' : DateFormat('HH:mm').format(d);
                return SideTitleWidget(
                  meta: meta,
                  space: 5,
                  child: Text(text, textAlign: TextAlign.center, style: labelStyle),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => t.dark ? const Color(0xFF020617) : const Color(0xFF0F172A),
            tooltipRoundedRadius: 10,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = items[groupIndex];
              final d = dates[groupIndex];
              return BarTooltipItem(
                'THỜI GIAN NỔ MÁY\n',
                const TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: '${item.elapsedMinutes.round()} phút\n',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: d != null ? DateFormat('HH:mm dd/MM/yy').format(d) : '—',
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: items[i].elapsedMinutes,
                  width: barW,
                  color: threshold > 0 && items[i].elapsedMinutes >= threshold ? FxTokens.red : FxTokens.indigo,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6.r)),
                ),
              ],
            ),
        ],
      ),
      duration: Duration.zero,
    );
  }
}
