import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:nguyenanh/core/ui_v2/fx_tokens.dart';
import 'package:nguyenanh/core/ui_v2/fx_ui.dart';
import 'package:nguyenanh/features/home/presentation/v2/widgets/home_modal_v2.dart';
import 'package:nguyenanh/features/order/data/models/order_model.dart';
import 'package:nguyenanh/features/order/order_service.dart';
import 'package:nguyenanh/l10n/app_localizations.dart';

/// "Đồng bộ lốt xe" dialog (v2). Same ordering, selection, "Apply trực sản xuất" (arrange time) and
/// "Đồng bộ" (sync lot to Google Sheets) flows and result messages as [SyncSlotsModal].
class SyncSlotsModalV2 extends StatefulWidget {
  final OrderService orderService;
  final List<OrderModel> activeFlowOrders;
  final VoidCallback onRefresh;

  const SyncSlotsModalV2({
    super.key,
    required this.orderService,
    required this.activeFlowOrders,
    required this.onRefresh,
  });

  @override
  State<SyncSlotsModalV2> createState() => _SyncSlotsModalV2State();
}

class _SyncSlotsModalV2State extends State<SyncSlotsModalV2> {
  bool _isSyncing = false;
  bool _isApplying = false;
  final List<int> _selectedOrderIds = [];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // ── Logic (identical to v1) ───────────────────────────────────────────────

  List<OrderModel> get _sortedOrders {
    final list = List<OrderModel>.from(widget.activeFlowOrders);
    list.sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
    return list;
  }

  void _showMessage(String title, String message, {bool isSuccess = false, VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (ctx) {
        final t = FxTokens.of(ctx);
        final tone = isSuccess ? FxTokens.emerald : FxTokens.red;
        return AlertDialog(
          icon: FxIconBadge(icon: isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded, tone: tone, size: 48),
          title: Text(title, textAlign: TextAlign.center, style: t.h1.copyWith(fontSize: 18.sp, color: t.ink(tone))),
          content: Text(message, textAlign: TextAlign.center, style: t.body.copyWith(color: t.textMuted)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (onOk != null) onOk();
                },
                child: const Text('OK'),
              ),
            ),
          ],
        );
      },
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
      if (mounted) {
        setState(() {
          _selectedOrderIds.clear();
        });
      }
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

  void _toggle(OrderModel order, bool? val) {
    setState(() {
      if (val == true) {
        _selectedOrderIds.add(order.orderId);
      } else {
        _selectedOrderIds.remove(order.orderId);
      }
    });
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Đang chờ';
      case 'collecting':
        return l10n.collecting;
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = FxTokens.of(context);
    final sortedOrders = _sortedOrders;
    final selected = sortedOrders.where((o) => _selectedOrderIds.contains(o.orderId)).length;

    return HomeModalFrameV2(
      icon: Icons.sync_rounded,
      tone: FxTokens.blue,
      title: homeSentenceV2(l10n.syncSlots),
      subtitle: 'Chọn các xe cần chuyển xuống cuối danh sách, sau đó bấm "Apply trực sản xuất".',
      maxHeightFactor: 0.88,
      toolbar: sortedOrders.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: selected > 0 ? t.soft(FxTokens.blue) : t.cardAlt,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: selected > 0 ? FxTokens.blue.withValues(alpha: 0.3) : t.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 17.sp, color: selected > 0 ? t.ink(FxTokens.blue) : t.textMuted),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      selected > 0 ? 'Đã chọn $selected xe để chuyển xuống cuối' : 'Chưa chọn xe nào',
                      style: t.small.copyWith(
                        color: selected > 0 ? t.ink(FxTokens.blue) : t.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '$selected/${sortedOrders.length}',
                    style: t.small.copyWith(color: t.text, fontWeight: FontWeight.w800, fontFeatures: FxTokens.tabular),
                  ),
                ],
              ),
            ),
      body: sortedOrders.isEmpty
          ? Center(child: FxEmpty(icon: Icons.inbox_outlined, title: l10n.noData))
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
              itemCount: sortedOrders.length,
              itemBuilder: (context, index) {
                final order = sortedOrders[index];
                final isSelected = _selectedOrderIds.contains(order.orderId);
                return _vehicleItem(t, order, index, isSelected);
              },
            ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isApplying ? null : _handleApplyToEnd,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h)),
              child: _isApplying
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const FittedBox(fit: BoxFit.scaleDown, child: Text('Apply trực sản xuất', maxLines: 1)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: FilledButton(
              onPressed: _isSyncing ? null : _handleSyncShift,
              style: FilledButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h)),
              child: _isSyncing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : FittedBox(fit: BoxFit.scaleDown, child: Text(homeSentenceV2(l10n.syncSlots), maxLines: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleItem(FxTokens t, OrderModel order, int index, bool isSelected) {
    final plate = order.vehicles?.vehicleLicensePlate ?? '';
    final name = order.vehicles?.vehicleName ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Material(
        color: isSelected ? Color.alphaBlend(t.soft(FxTokens.blue), t.card) : t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FxTokens.rTile),
          side: BorderSide(color: isSelected ? FxTokens.blue.withValues(alpha: 0.55) : t.border.withValues(alpha: 0.8)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _toggle(order, !isSelected),
          child: Padding(
            padding: EdgeInsets.fromLTRB(4.w, 8.h, 12.w, 8.h),
            child: Row(
              children: [
                Checkbox(value: isSelected, onChanged: (val) => _toggle(order, val)),
                Container(
                  constraints: BoxConstraints(minWidth: 30.w),
                  height: 30.w,
                  padding: EdgeInsets.symmetric(horizontal: 5.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? FxTokens.blue : t.cardAlt,
                    borderRadius: BorderRadius.circular(9.r),
                    border: Border.all(color: isSelected ? FxTokens.blue : t.border),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: t.num(12.5.sp, color: isSelected ? Colors.white : t.textMuted),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate.isNotEmpty ? plate : '—',
                        style: t.h3.copyWith(fontSize: 14.sp, fontFeatures: FxTokens.tabular),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (name.isNotEmpty) ...[
                        SizedBox(height: 1.h),
                        Text(name, style: t.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                if (order.orderStatus.isNotEmpty) FxPill(label: _statusLabel(order.orderStatus), tone: FxTokens.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
