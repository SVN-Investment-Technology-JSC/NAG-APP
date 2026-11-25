import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/home_modal_v2.dart';
import 'package:nguyenanh/features/vehicle/data/models/end_of_day_model.dart';
import 'package:nguyenanh/features/vehicle/data/services/vehicle_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Nhật ký vận hành" (check log) dialog (v2). Same loading per day, day navigation, date picker and
/// search as [EndOfDayModal]; only the presentation is new (vehicles are paged 10 at a time).
class EndOfDayModalV2 extends StatefulWidget {
  final VehicleService vehicleService;

  const EndOfDayModalV2({super.key, required this.vehicleService});

  @override
  State<EndOfDayModalV2> createState() => _EndOfDayModalV2State();
}

class _EndOfDayModalV2State extends State<EndOfDayModalV2> {
  static const _perPage = 10;

  bool _isLoading = false;
  EndOfDayStatusResponse? _data;
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // presentation only
  int _page = 0;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _page = 0;
    });
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final res = await widget.vehicleService.getEndOfDayStatus(dateStr);
    if (mounted) {
      setState(() {
        _data = res;
        _isLoading = false;
      });
    }
  }

  void _goDay(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _fetchData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchData();
    }
  }

  List<EndOfDayVehicle> get _filtered =>
      _data?.vehicles.where((v) {
        if (_searchQuery.isEmpty) return true;
        return v.vehicleName.toLowerCase().contains(_searchQuery) ||
            v.vehicleLicensePlate.toLowerCase().contains(_searchQuery);
      }).toList() ??
      [];

  /// The log lines of a vehicle as (message, isWarning) — same rules as v1.
  List<(String, bool)> _logLines(EndOfDayVehicle vehicle) {
    final lines = <(String, bool)>[];
    if (vehicle.operationItems != null && vehicle.operationItems!.isNotEmpty) {
      for (final item in vehicle.operationItems!) {
        final isWarning = item.level.toLowerCase() == 'warning';
        lines.add((item.message, isWarning));
      }
    } else {
      // Fallback to operationNote/operationNotes
      final notes = vehicle.operationNotes ?? vehicle.operationNote.split(' | ');
      for (final note in notes) {
        if (note.trim().isEmpty) continue;
        final isWarning = note.toLowerCase().contains('bat thuong') || note.toLowerCase().contains('bất thường');
        lines.add((note.trim(), isWarning));
      }
    }
    return lines;
  }

  String _finishTime(EndOfDayVehicle vehicle) {
    if (vehicle.finishedAt == null) return '-';
    try {
      return DateFormat('HH:mm')
          .format(DateTime.parse(vehicle.finishedAt!.endsWith('Z') ? vehicle.finishedAt! : '${vehicle.finishedAt!}Z').toLocal());
    } catch (_) {
      return '-';
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final vehicles = _filtered;
    final showPager = !_isLoading && vehicles.length > _perPage;
    final abnormal = _data?.abnormalTotal ?? 0;

    return HomeModalFrameV2(
      icon: Icons.fact_check_outlined,
      tone: FxTokens.blue,
      title: l10n.operationalLog,
      subtitle: _data != null ? l10n.totalVehicles(_data!.total) : 'Trạng thái và ghi chú vận hành của xe trong ngày',
      pills: [
        if (_data != null && abnormal > 0)
          FxPill(label: '$abnormal xe bất thường', tone: FxTokens.red, icon: Icons.error_outline_rounded),
      ],
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeDateNavV2(
            date: _selectedDate,
            onPrev: () => _goDay(-1),
            onNext: isToday ? null : () => _goDay(1),
            onPick: _pickDate,
          ),
          SizedBox(height: 10.h),
          FxSearchField(
            controller: _searchController,
            hint: l10n.searchVehicleHint,
            onChanged: (val) => setState(() {
              _searchQuery = val.trim().toLowerCase();
              _page = 0;
            }),
          ),
        ],
      ),
      body: _isLoading ? HomeListSkeletonV2(height: 120.h, count: 4) : _content(t, vehicles),
      footer: showPager
          ? FxPager(page: _page, total: vehicles.length, size: _perPage, onChanged: (p) => setState(() => _page = p))
          : null,
    );
  }

  Widget _content(FxTokens t, List<EndOfDayVehicle> vehicles) {
    final dateText = DateFormat('dd/MM/yyyy').format(_selectedDate);
    if (_data == null) {
      return Center(
        child: SingleChildScrollView(
          child: FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: '${l10n.noData} $dateText',
            message: 'Không tải được nhật ký vận hành. Kiểm tra kết nối rồi thử lại.',
            action: FilledButton.tonalIcon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ),
        ),
      );
    }
    if (vehicles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: FxEmpty(
            icon: _searchQuery.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
            title: _searchQuery.isEmpty ? '${l10n.noData} $dateText' : l10n.noTripsFound,
          ),
        ),
      );
    }

    final page = fxPage(vehicles, _page, _perPage);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: page.length,
      itemBuilder: (context, index) => _vehicleCard(t, page[index]),
    );
  }

  Widget _vehicleCard(FxTokens t, EndOfDayVehicle vehicle) {
    final lines = _logLines(vehicle);
    final hasWarning = lines.any((l) => l.$2);
    final finish = _finishTime(vehicle);

    return FxCard(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      borderColor: hasWarning ? FxTokens.red.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FxIconBadge(
                icon: Icons.local_shipping_rounded,
                tone: hasWarning ? FxTokens.red : FxTokens.blue,
                size: 34,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vehicle.vehicleName, style: t.h3.copyWith(fontSize: 14.sp), maxLines: 1, overflow: TextOverflow.ellipsis),
                    SizedBox(height: 1.h),
                    Text(
                      vehicle.vehicleLicensePlate,
                      style: t.small.copyWith(
                        color: t.ink(FxTokens.blue),
                        fontWeight: FontWeight.w700,
                        fontFeatures: FxTokens.tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('KẾT THÚC', style: t.overline),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded, size: 13.sp, color: t.textFaint),
                      SizedBox(width: 4.w),
                      Text(finish, style: t.num(14.sp)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 2.h),
            decoration: BoxDecoration(
              color: t.cardAlt,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: t.border.withValues(alpha: 0.7)),
            ),
            child: lines.isEmpty
                ? Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text('-', style: t.body.copyWith(color: t.textMuted)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final l in lines)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(top: 1.h),
                                child: Icon(
                                  l.$2 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                                  size: 16.sp,
                                  color: t.ink(l.$2 ? FxTokens.red : FxTokens.emerald),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  l.$1,
                                  style: t.body.copyWith(
                                    color: l.$2 ? t.ink(FxTokens.red) : t.text,
                                    fontWeight: l.$2 ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
