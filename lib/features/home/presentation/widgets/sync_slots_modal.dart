import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

class SyncSlotsModal extends StatefulWidget {
  final OrderService orderService;
  final List<OrderModel> activeFlowOrders;
  final VoidCallback onRefresh;

  const SyncSlotsModal({
    super.key,
    required this.orderService,
    required this.activeFlowOrders,
    required this.onRefresh,
  });

  @override
  State<SyncSlotsModal> createState() => _SyncSlotsModalState();
}

class _SyncSlotsModalState extends State<SyncSlotsModal> {
  bool _isSyncing = false;
  bool _isApplying = false;
  final List<int> _selectedOrderIds = [];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  List<OrderModel> get _sortedOrders {
    final list = List<OrderModel>.from(widget.activeFlowOrders);
    list.sort((a, b) => (a.orderNumber ?? 0).compareTo(b.orderNumber ?? 0));
    return list;
  }

  void _showMessage(String title, String message, {bool isSuccess = false, VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (onOk != null) onOk();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApplyToEnd() async {
    if (_selectedOrderIds.isEmpty) {
      _showMessage('Thông báo', 'Chưa chọn xe nào!');
      return;
    }

    setState(() => _isApplying = true);
    try {
      final vehicleIds = widget.activeFlowOrders
          .where((o) => _selectedOrderIds.contains(o.orderId))
          .map((o) => o.vehicles?.vehicleId)
          .whereType<int>()
          .toList();

      if (vehicleIds.isEmpty) {
        setState(() => _isApplying = false);
        return;
      }

      await widget.orderService.arrangeTime(vehicleIds: vehicleIds);
      widget.onRefresh();
      setState(() {
        _selectedOrderIds.clear();
      });
      if (mounted) {
        _showMessage('Thành công', 'Đã chuyển ${vehicleIds.length} xe xuống cuối!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi', 'Lỗi: $e');
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _handleSyncShift() async {
    setState(() => _isSyncing = true);
    try {
      final sorted = _sortedOrders;
      final maToStt = <String, int>{};
      int stt = 1;

      for (final o in sorted) {
        final raw = o.vehicles?.vehicleName;
        if (raw == null || raw.isEmpty) continue;
        
        final upper = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final RegExp regex = RegExp(r'^X0*(\d+)$');
        final match = regex.firstMatch(upper);
        final maX = match != null ? 'X${match.group(1)}' : upper;

        if (!RegExp(r'^X\d+$').hasMatch(maX)) continue;
        if (maToStt.containsKey(maX)) continue;

        maToStt[maX] = stt++;
      }

      await widget.orderService.syncLot(maToStt: maToStt);
      if (mounted) {
        _showMessage('Thành công', 'Đồng bộ thành công ${maToStt.length} xe!', isSuccess: true, onOk: () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi đồng bộ', 'Chi tiết: $e');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortedOrders = _sortedOrders;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 0.95.sw,
          height: 0.85.sh,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24.r),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildHeader(colorScheme, theme),
              Expanded(
                child: sortedOrders.isEmpty
                    ? Center(child: Text(l10n.noData, style: theme.textTheme.bodyLarge))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        itemCount: sortedOrders.length,
                        itemBuilder: (context, index) {
                          final order = sortedOrders[index];
                          final isSelected = _selectedOrderIds.contains(order.orderId);
                          return _buildVehicleItem(order, index, isSelected, colorScheme, theme);
                        },
                      ),
              ),
              _buildFooter(colorScheme, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(Icons.sync_rounded, color: colorScheme.primary, size: 28.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.syncSlots,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Chọn các xe cần chuyển xuống cuối danh sách, sau đó bấm \"Apply trực sản xuất\".',
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleItem(OrderModel order, int index, bool isSelected, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surface,
        border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (val) {
          setState(() {
            if (val == true) {
              _selectedOrderIds.add(order.orderId);
            } else {
              _selectedOrderIds.remove(order.orderId);
            }
          });
        },
        title: Text(
          '${index + 1}. ${order.vehicles?.vehicleLicensePlate ?? ""} | ${order.vehicles?.vehicleName ?? ""}',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          order.orderStatus ?? '',
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isApplying ? null : _handleApplyToEnd,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: _isApplying
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Apply trực sản xuất'),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: FilledButton(
              onPressed: _isSyncing ? null : _handleSyncShift,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              child: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.syncSlots),
            ),
          ),
        ],
      ),
    );
  }
}
