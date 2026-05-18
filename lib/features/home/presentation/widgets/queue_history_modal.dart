import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:nguyenanh/core/network/api_client.dart';
import 'package:nguyenanh/features/order/data/models/tanker_queue_snapshot_item.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class QueueHistoryModal extends StatefulWidget {
  const QueueHistoryModal({super.key});

  @override
  State<QueueHistoryModal> createState() => _QueueHistoryModalState();
}

class _QueueHistoryModalState extends State<QueueHistoryModal> {
  late OrderService _orderService;
  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  List<TankerQueueSnapshotItem> _items = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final items = await _orderService.getTankerQueueSnapshot(dateStr);
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 0.95.sw,
          height: 0.9.sh,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: colorScheme.surface,
                body: Column(
                  children: [
                    // Header
                    _buildHeader(colorScheme, theme, isToday),
                    
                    // Content
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildContent(colorScheme, theme),
                    ),
                    
                    // Footer (Search only)
                    _buildFooter(colorScheme, theme),
                  ],
                ),
              ),
              // Absolute Positioned Close Button (Top Right)
              Positioned(
                top: 12.h,
                right: 12.w,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, size: 24.sp, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme, bool isToday) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.history, color: colorScheme.primary, size: 24.sp),
              ),
              SizedBox(width: 16.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.queueHistory,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                    ),
                  ),
                  if (!_isLoading && _error == null)
                    Text(
                      'Tổng: ${_items.length} xe',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Date Navigator Row
          _buildDateNavigator(colorScheme, theme, isToday),
        ],
      ),
    );
  }

  Widget _buildDateNavigator(ColorScheme colorScheme, ThemeData theme, bool isToday) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _goDay(-1),
            icon: Icon(Icons.chevron_left, size: 20.sp),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.all(8.w),
          ),
          InkWell(
            onTap: () async {
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
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.calendar_today_outlined, size: 14.sp, color: colorScheme.primary),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: isToday ? null : () => _goDay(1),
            icon: Icon(Icons.chevron_right, size: 20.sp),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.all(8.w),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: colorScheme.error),
            SizedBox(height: 16.h),
            Text(_error!, style: TextStyle(color: colorScheme.error)),
          ],
        ),
      );
    }

    final filteredItems = _items.where((v) {
      if (_searchQuery.isEmpty) return true;
      return v.vehicleName.toLowerCase().contains(_searchQuery) ||
          v.vehicleLicensePlate.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64.sp, color: colorScheme.outline),
            SizedBox(height: 16.h),
            Text(
              _searchQuery.isEmpty
                  ? 'Chưa có lịch sử lốt xe ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'
                  : l10n.noTripsFound,
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(20.w),
      itemCount: filteredItems.length,
      separatorBuilder: (context, index) => Divider(height: 32.h, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final item = filteredItems[index];
        return _buildVehicleRow(item, colorScheme, theme);
      },
    );
  }

  Widget _buildVehicleRow(TankerQueueSnapshotItem item, ColorScheme colorScheme, ThemeData theme) {
    return Row(
      children: [
        // Position number
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            item.position.toString(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // Vehicle Name
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(
            item.vehicleName,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // License Plate
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            item.vehicleLicensePlate,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ColorScheme colorScheme, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 40.h,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: l10n.searchVehicleHint,
          prefixIcon: Icon(Icons.search, size: 18.sp, color: colorScheme.onSurfaceVariant),
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: colorScheme.primary, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: _buildSearchField(colorScheme, theme),
    );
  }
}
