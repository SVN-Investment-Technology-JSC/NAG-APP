import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/home_modal_v2.dart';
import 'package:nguyenanh/features/order/data/models/tanker_queue_snapshot_item.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Lịch sử lốt xe" dialog (v2). Same snapshot loading per day (yesterday by default), day navigation,
/// date picker and search as [QueueHistoryModal]; only the presentation is new (paged 20 at a time).
class QueueHistoryModalV2 extends StatefulWidget {
  const QueueHistoryModalV2({super.key});

  @override
  State<QueueHistoryModalV2> createState() => _QueueHistoryModalV2State();
}

class _QueueHistoryModalV2State extends State<QueueHistoryModalV2> {
  static const _perPage = 20;

  late OrderService _orderService;
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  List<TankerQueueSnapshotItem> _items = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // presentation only
  int _page = 0;

  // ── Logic (identical to v1; setState guarded by `mounted`) ────────────────

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _orderService = OrderService(ApiClient.dio);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 0;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final items = await _orderService.getTankerQueueSnapshot(dateStr);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được lịch sử lốt xe';
        _items = [];
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

  List<TankerQueueSnapshotItem> get _filtered => _items.where((v) {
        if (_searchQuery.isEmpty) return true;
        return v.vehicleName.toLowerCase().contains(_searchQuery) ||
            v.vehicleLicensePlate.toLowerCase().contains(_searchQuery);
      }).toList();

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final filtered = _filtered;
    final showPager = !_isLoading && _error == null && filtered.length > _perPage;

    return HomeModalFrameV2(
      icon: Icons.history_rounded,
      tone: FxTokens.violet,
      title: homeSentenceV2(l10n.queueHistory),
      subtitle: !_isLoading && _error == null ? 'Tổng: ${_items.length} xe' : 'Thứ tự lốt xe bồn chốt theo ngày',
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
      body: _isLoading ? HomeListSkeletonV2(height: 58.h, count: 7) : _content(t, l10n, filtered),
      footer: showPager
          ? FxPager(page: _page, total: filtered.length, size: _perPage, onChanged: (p) => setState(() => _page = p))
          : null,
    );
  }

  Widget _content(FxTokens t, AppLocalizations l10n, List<TankerQueueSnapshotItem> filtered) {
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          child: FxEmpty(
            icon: Icons.cloud_off_rounded,
            title: _error!,
            message: 'Kiểm tra kết nối mạng rồi thử lại.',
            action: FilledButton.tonalIcon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.retry),
            ),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: FxEmpty(
            icon: _searchQuery.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
            title: _searchQuery.isEmpty
                ? 'Chưa có lịch sử lốt xe ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'
                : l10n.noTripsFound,
          ),
        ),
      );
    }

    final page = fxPage(filtered, _page, _perPage);
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: page.length,
      itemBuilder: (context, index) => _row(t, page[index]),
    );
  }

  Widget _row(FxTokens t, TankerQueueSnapshotItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(FxTokens.rTile),
        border: Border.all(color: t.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            constraints: BoxConstraints(minWidth: 34.w),
            height: 34.w,
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.soft(FxTokens.violet), borderRadius: BorderRadius.circular(10.r)),
            child: Text('${item.position}', style: t.num(14.sp, color: t.ink(FxTokens.violet))),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              item.vehicleName,
              style: t.h3.copyWith(fontSize: 14.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: t.soft(FxTokens.blue),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: FxTokens.blue.withValues(alpha: 0.25)),
            ),
            child: Text(
              item.vehicleLicensePlate,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: t.ink(FxTokens.blue),
                fontFeatures: FxTokens.tabular,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
