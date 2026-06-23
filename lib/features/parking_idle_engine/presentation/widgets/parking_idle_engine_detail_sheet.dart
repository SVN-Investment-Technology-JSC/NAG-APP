import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/models/parking_idle_engine_models.dart';
import 'package:nguyenanh/features/parking_idle_engine/data/services/parking_idle_engine_service.dart';

class ParkingIdleEngineDetailSheet extends StatefulWidget {
  final ParkingIdleEngineAlert alert;
  final ParkingIdleEngineService apiService;

  const ParkingIdleEngineDetailSheet({
    super.key,
    required this.alert,
    required this.apiService,
  });

  static void show(BuildContext context, ParkingIdleEngineAlert alert, ParkingIdleEngineService apiService) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParkingIdleEngineDetailSheet(alert: alert, apiService: apiService),
    );
  }

  @override
  State<ParkingIdleEngineDetailSheet> createState() => _ParkingIdleEngineDetailSheetState();
}

class _ParkingIdleEngineDetailSheetState extends State<ParkingIdleEngineDetailSheet> {
  bool _historyLoading = false;
  ParkingIdleEngineHistoryResponse? _historyData;
  int _historyPage = 1;
  final int _historyLimit = 10;

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 0)); // Today start
  DateTime _toDate = DateTime.now(); // Today end

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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF6366F1),
                ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _fromDate = DateTime(
          pickedRange.start.year,
          pickedRange.start.month,
          pickedRange.start.day,
          0,
          0,
          0,
        );
        _toDate = DateTime(
          pickedRange.end.year,
          pickedRange.end.month,
          pickedRange.end.day,
          23,
          59,
          59,
        );
        _historyPage = 1;
      });
      _fetchHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.symmetric(vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chi tiết nổ máy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${widget.alert.vehicleName} - ${widget.alert.vehicleLicensePlate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bar Chart Section
                  _buildChartCard(theme, colorScheme),

                  SizedBox(height: 16.h),

                  // History Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded, color: const Color(0xFF6366F1), size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'Lịch sử các phiên nổ máy',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      // Date range picker trigger button
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: Icon(Icons.calendar_today_rounded, size: 12.sp),
                        label: Text(
                          '${DateFormat('dd/MM').format(_fromDate)} - ${DateFormat('dd/MM').format(_toDate)}',
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 0),
                          minimumSize: Size(0, 28.h),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8.h),

                  // History List Table
                  _buildHistoryList(theme, colorScheme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme, ColorScheme colorScheme) {
    final list = _historyData?.items ?? [];
    // Slice and reverse just like React: `historyData.items.slice().reverse()`
    final chartList = list.toList().reversed.toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: const Color(0xFF6366F1), size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  'Biểu đồ thời gian nổ máy theo phiên',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            if (_historyLoading && _historyData == null)
              SizedBox(
                height: 160.h,
                child: const Center(child: CircularProgressIndicator.adaptive()),
              )
            else if (chartList.isEmpty)
              SizedBox(
                height: 160.h,
                child: const Center(
                  child: Text(
                    'Không có dữ liệu',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              SizedBox(
                height: 180.h,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: chartList
                            .map((e) => e.elapsedMinutes)
                            .fold<double>(0, (max, v) => v > max ? v : max) *
                        1.2,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => Colors.indigo[900]!,
                        tooltipRoundedRadius: 8.r,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = chartList[groupIndex];
                          final timeStr = DateFormat('HH:mm dd/MM/yy').format(DateTime.parse(item.idleStartedAt).toLocal());
                          return BarTooltipItem(
                            'THỜI GIAN NỔ MÁY\n',
                            TextStyle(color: Colors.white60, fontSize: 8.sp, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: '${item.elapsedMinutes.round()} phút\n',
                                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
                              ),
                              TextSpan(
                                text: timeStr,
                                style: TextStyle(color: Colors.white70, fontSize: 10.sp, fontWeight: FontWeight.w500),
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
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < chartList.length) {
                              final item = chartList[idx];
                              try {
                                final dt = DateTime.parse(item.idleStartedAt).toLocal();
                                final text = DateFormat('dd/MM').format(dt);
                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4.h,
                                  child: Text(
                                    text,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 9.sp, fontWeight: FontWeight.bold),
                                  ),
                                );
                              } catch (_) {}
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 22.h,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32.w,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}p',
                              style: TextStyle(color: Colors.grey[400], fontSize: 9.sp, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey[100]!,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(chartList.length, (idx) {
                      final item = chartList[idx];
                      return BarChartGroupData(
                        x: idx,
                        barRods: [
                          BarChartRodData(
                            toY: item.elapsedMinutes,
                            color: const Color(0xFF818CF8),
                            width: 14.w,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(4.r),
                              topRight: Radius.circular(4.r),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme, ColorScheme colorScheme) {
    if (_historyLoading && _historyData == null) {
      return SizedBox(
        height: 150.h,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final items = _historyData?.items ?? [];

    if (items.isEmpty) {
      return SizedBox(
        height: 150.h,
        child: const Center(
          child: Text(
            'Không có dữ liệu phiên nổ máy',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Column(
      children: [
        // List of history cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => SizedBox(height: 6.h),
          itemBuilder: (context, idx) {
            final item = items[idx];
            String startStr = '—';
            String endStr = '—';
            try {
              final startDt = DateTime.parse(item.idleStartedAt).toLocal();
              startStr = DateFormat('HH:mm - dd/MM').format(startDt);
            } catch (_) {}
            try {
              if (item.idleEndedAt != null) {
                final endDt = DateTime.parse(item.idleEndedAt!).toLocal();
                endStr = DateFormat('HH:mm - dd/MM').format(endDt);
              }
            } catch (_) {}

            return Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bắt đầu',
                            style: TextStyle(fontSize: 9.sp, color: Colors.grey[400], fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            startStr,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kết thúc',
                            style: TextStyle(fontSize: 9.sp, color: Colors.grey[400], fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            endStr,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '${item.elapsedMinutes.round()}p',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        SizedBox(height: 12.h),

        // Pagination controls
        if (_historyData != null && _historyData!.total > _historyLimit)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _historyPage > 1
                    ? () {
                        setState(() {
                          _historyPage--;
                        });
                        _fetchHistory();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Trang $_historyPage / ${(_historyData!.total / _historyLimit).ceil()}',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: _historyPage < (_historyData!.total / _historyLimit).ceil()
                    ? () {
                        setState(() {
                          _historyPage++;
                        });
                        _fetchHistory();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }
}
